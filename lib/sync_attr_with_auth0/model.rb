module SyncAttrWithAuth0
  module Model
    extend ::ActiveSupport::Concern

    module ClassMethods

      def sync_attr_with_auth0(options = {})
        class_attribute :uid_att
        class_attribute :email_att
        class_attribute :password_att
        class_attribute :email_verified_att
        class_attribute :connection_name
        class_attribute :sync_atts

        _options = merge_default_options(options)

        self.uid_att = _options[:uid_att]
        self.email_att = _options[:email_att]
        self.password_att = _options[:password_att]
        self.email_verified_att = _options[:email_verified_att]
        self.connection_name = _options[:connection_name]
        self.sync_atts = _options[:sync_atts].collect(&:to_s)

        after_validation :validate_email_with_auth0
        after_create :create_user_in_auth0
        after_update :sync_attr_with_auth0
      end

    private

      def merge_default_options(options)
        _options = {
          uid_att: :uid,
          email_att: :email,
          password_att: :password,
          email_verified_att: :email_verified,
          connection_name: 'Username-Password-Authentication',
          sync_atts: []
        }

        _options.merge!(options)

        return _options
      end

    end

    def validate_email_with_auth0
      # If the email is being modified, verify the new email does not already
      # exist in auth0.

      ok_to_validate = (self.respond_to?(:validate_with_auth0) ? self.validate_with_auth0 : true)

      if ok_to_validate and self.email_changed?
        # Get an access token
        access_token = SyncAttrWithAuth0::Auth0.get_access_token

        response = SyncAttrWithAuth0::Auth0.make_request(
          access_token,
          'get',
          "/api/users?search=email:#{self.email}")

        return JSON.parse(response).empty?
      end

      return true
    end

    def create_user_in_auth0
      # When creating a new user, create the user in auth0.

      ok_to_sync = (self.respond_to?(:sync_with_auth0_on_create) ? self.sync_with_auth0_on_create : true)

      if ok_to_sync
        # Get an access token
        access_token = SyncAttrWithAuth0::Auth0.get_access_token

        # Look for matches between what's changing
        # and what needs to be transmitted to Auth0
        matches = ( (self.class.sync_atts || []) & (self.changes.keys || []) )

        # Figure out what needs to be sent to Auth0
        changes = {}
        matches.each do |m|
          changes[m] = self.send(m)
        end

        unless changes['email'].nil?
          # Email is already being sent
          changes.delete('email')
        end

        unless changes['password'].nil?
          # Password is already being sent
          changes.delete('password')
        end

        response = SyncAttrWithAuth0::Auth0.make_request(
          access_token,
          'post',
          "/api/users",
          {
            'email' => self.send(email_att),
            'password' => self.send(password_att),
            'connection' => connection_name,
            'email_verified' => self.send(email_verified_att)
          }.merge(changes))

        response = JSON.parse(response)

        # Update the record with the uid
        self.send("#{uid_att}=", response['user_id'])
        self.save
      end

      true # don't abort the callback chain
    end

    def sync_attr_with_auth0
      ok_to_sync = (self.respond_to?(:sync_with_auth0_on_update) ? self.sync_with_auth0_on_update : true)

      if ok_to_sync
        # Look for matches between what's changing
        # and what needs to be transmitted to Auth0
        matches = ( (self.class.sync_atts || []) & (self.changes.keys || []) )

        # If we find matches
        unless matches.empty?

          # Get an access token
          access_token = SyncAttrWithAuth0::Auth0.get_access_token

          # Figure out what needs to be sent to Auth0
          changes = {}
          matches.each do |m|
            changes[m] = self.send(m)
          end

          # If we actually have changes
          unless changes.empty?
            # Get the auth0 uid
            uid = self.send(uid_att)

            # Don't try to update auth0 if the user doesn't have a uid
            unless uid.nil?
              # Determine if the email was changed
              unless changes['email'].nil?
                email = changes.delete('email')

                response = SyncAttrWithAuth0::Auth0.make_request(
                  access_token,
                  'put',
                  "/api/users/#{::URI.escape(uid)}/email",
                  {
                    'email' => email,
                    'verify' => false # If the user were to fail to verify it would create a discrepency between auth0 and the local database
                  })
              end

              # Determine if the password was changed
              unless changes['password'].nil?
                password = changes.delete('password')

                response = SyncAttrWithAuth0::Auth0.make_request(
                  access_token,
                  'put',
                  "/api/users/#{::URI.escape(uid)}/password",
                  {
                    'password' => password,
                    'verify' => true
                  })
              end

              # Patch the changes
              response = SyncAttrWithAuth0::Auth0.make_request(
                access_token,
                'patch',
                "/api/users/#{::URI.escape(uid)}/metadata",
                changes)
            end

          end
        end

      end

      true # don't abort the callback chain
    end

  end
end
