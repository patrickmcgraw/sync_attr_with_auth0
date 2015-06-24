module SyncAttrWithAuth0
  module Model
    extend ::ActiveSupport::Concern

    require "uuidtools"

    module ClassMethods

      def sync_attr_with_auth0(options = {})
        class_attribute :auth0_sync_options

        verify_environment_variables
        merge_default_options(options)

        after_validation :validate_email_with_auth0
        after_create :auth0_create
        after_update :auth0_update
      end

    private

      def verify_environment_variables
        env_variables = %w(AUTH0_GLOBAL_CLIENT_ID AUTH0_GLOBAL_CLIENT_SECRET AUTH0_CLIENT_ID AUTH0_CLIENT_SECRET AUTH0_DOMAIN)
        missing_env_variables = []

        env_variables.each do |env_variable_name|
          unless ENV[env_variable_name]
            missing_env_variables << env_variable_name
          end
        end

        if missing_env_variables.size > 0
          raise Exception.new("Missing the following required environment variables: #{missing_env_variables.join(',')}")
        end
      end

      def merge_default_options(options)
        self.auth0_sync_options = {
          uid_att: :uid,
          name_att: :name,
          given_name_att: :given_name,
          family_name_att: :family_name,
          email_att: :email,
          password_att: :password,
          email_verified_att: :email_verified,
          verify_password_att: :verify_password,
          connection_name: 'Username-Password-Authentication',
          sync_atts: []
        }

        self.auth0_sync_options.merge!(options)
      end

    end

    def validate_email_with_auth0
      # If the email is being modified, verify the new email does not already
      # exist in auth0.

      ok_to_validate = (self.respond_to?(:validate_with_auth0) and !self.validate_with_auth0.nil? ? self.validate_with_auth0 : true)

      if ok_to_validate and self.email_changed?
        response = find_user_in_auth0

        return response.empty?
      end

      return true
    end

    def auth0_create
      # When creating a new user, create the user in auth0.

      ok_to_sync = (self.respond_to?(:sync_with_auth0_on_create) and !self.sync_with_auth0_on_create.nil?  ? self.sync_with_auth0_on_create : true)

      # Do not create a user in auth0 if the user already has a uid from auth0
      if ok_to_sync
        unless self.send(auth0_sync_options[:uid_att]).nil? or self.send(auth0_sync_options[:uid_att]).empty?
          ok_to_sync = false
        end
      end

      if ok_to_sync
        create_user_in_auth0
      end

      true # don't abort the callback chain
    end

    def auth0_update
      ok_to_sync = (self.respond_to?(:sync_with_auth0_on_update) and !self.sync_with_auth0_on_update.nil? ? self.sync_with_auth0_on_update : true)

      if ok_to_sync

        # Get the auth0 uid
        uid = self.send(auth0_sync_options[:uid_att])

        # TODO: create a user if the uid is nil
        unless uid.nil?
          # Update the user in auth0
          update_user_in_auth0(uid)
        end

      end

      true # don't abort the callback chain
    end

    def create_user_in_auth0()
      user_metadata = auth0_user_metadata

      password = auth0_user_password

      if password.nil?
        password = auth0_default_password
      end

      email_verified = auth0_email_verified?
      args = {
        'email' => self.send(auth0_sync_options[:email_att]),
        'password' => password,
        'connection' => auth0_sync_options[:connection_name],
        'email_verified' => email_verified,
        'user_metadata' => user_metadata
      }

      auth0 = SyncAttrWithAuth0::Auth0.create_auth0_client

      response = auth0.create_user(self.send(auth0_sync_options[:name_att]), args)

      # Update the record with the uid
      self.send("#{auth0_sync_options[:uid_att]}=", response['user_id'])
      self.save
    end

    def update_user_in_auth0(uid)
      user_metadata = auth0_user_metadata

      auth0 = SyncAttrWithAuth0::Auth0.create_auth0_client

      args = {
        'app_metadata' => {
          'name' => self.send(auth0_sync_options[:name_att]),
          'nickname' => self.send(auth0_sync_options[:name_att]),
          'given_name' => self.send(auth0_sync_options[:given_name_att]),
          'family_name' => self.send(auth0_sync_options[:family_name_att])
        }
      }

      if (
        auth0_sync_options[:sync_atts].index(auth0_sync_options[:password_att]) and
        # Because the password being passed to auth0 probably is not a real
        # field (and if it is it needs to be the unencrypted value), we
        # can't rely on checking if the password attribute changed (chances
        # are, that method does not exist). So assume the password attribute
        # is only set if it's being changed.
        !self.send(auth0_sync_options[:password_att]).nil?
      )
        # The password should be sync'd and was changed
        args['password'] = self.send(auth0_sync_options[:password_att])
        args['verify_password'] = auth0_verify_password?
      end

      args['user_metadata'] = user_metadata

      begin
        auth0.patch_user(uid, args)

      rescue ::Auth0::NotFound => e
        # TODO: We need to attempt to find the correct UID by email or nil the UID on the user.
        response = find_user_in_auth0
        found_user = response.first

        if found_user.nil?
          # Could not find the user, create it in auth0
          create_user_in_auth0
        else
          # Update with the new uid and correct the one on file
          auth0 = SyncAttrWithAuth0::Auth0.create_auth0_client
          auth0.patch_user(found_user['user_id'], args)

          self.send("#{auth0_sync_options[:uid_att]}=", found_user['user_id'])
          self.save
        end

      rescue Exception => e
        ::Rails.logger.error e.message
        ::Rails.logger.error e.backtrace.join("\n")

        raise e
      end
    end

    def find_user_in_auth0
      auth0 = SyncAttrWithAuth0::Auth0.create_auth0_client(api_version: 1)

      response = auth0.users("email:#{self.send(auth0_sync_options[:email_att])}")

      return response
    end

    def auth0_user_password
      self.respond_to?(auth0_sync_options[:password_att]) ? self.send(auth0_sync_options[:password_att]) : auth0_default_password
    end

    def auth0_email_verified?
      !!(self.respond_to?(auth0_sync_options[:email_verified_att]) ? self.send(auth0_sync_options[:email_verified_att]) : false)
    end

    def auth0_verify_password?
      !!(self.respond_to?(auth0_sync_options[:verify_password_att]) ? self.send(auth0_sync_options[:verify_password_att]) : true)
    end

    def auth0_default_password
      # Need a9 or something similar to guarantee one letter and one number in the password
      "#{auth0_new_uuid[0..19]}aA9"
    end

    def auth0_new_uuid
      ::UUIDTools::UUID.random_create().to_s
    end

    def auth0_user_metadata
      user_metadata = {}
      app_metadata_keys = [auth0_sync_options[:family_name_att],
        auth0_sync_options[:given_name_att], auth0_sync_options[:email_att],
        auth0_sync_options[:password_att],
        auth0_sync_options[:email_verified_att], auth0_sync_options[:name_att]]

      auth0_sync_options[:sync_atts].each do |key|
        user_metadata[key] = self.send(key) if self.respond_to?(key) and app_metadata_keys.index(key).nil?
      end

      return user_metadata
    end

  end
end
