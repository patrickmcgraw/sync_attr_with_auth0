module SyncAttrWithAuth0
  module Adapters
    module ActiveRecord
      module Auth0Sync

        def sync_password_with_auth0?
          !!(auth0_attributes_to_sync.index(auth0_sync_configuration.password_attribute))
        end # sync_password_with_auth0?


        def sync_email_with_auth0?
          !!(auth0_attributes_to_sync.index(auth0_sync_configuration.email_attribute))
        end # sync_email_with_auth0?


        def sync_with_auth0_on_create?
          !!((self.respond_to?(:sync_with_auth0_on_create) and !self.sync_with_auth0_on_create.nil?) ? self.sync_with_auth0_on_create : true)
        end # sync_with_auth0_on_create?


        def sync_with_auth0_on_update?
          !!((self.respond_to?(:sync_with_auth0_on_update) and !self.sync_with_auth0_on_update.nil?) ? self.sync_with_auth0_on_update : true)
        end # sync_with_auth0_on_update?


        def save_to_auth0_on_create
          return true unless sync_with_auth0_on_create?

          save_to_auth0

          true # don't abort the callback chain
        end # save_to_auth0_on_create


        def save_to_auth0_on_update
          return true unless sync_with_auth0_on_update?
          return true unless auth0_dirty?

          save_to_auth0

          true # don't abort the callback chain
        end # save_to_auth0_on_update


        def auth0_dirty?
          is_dirty = !!(
            auth0_attributes_to_sync.inject(false) do |memo, attrib|
              memo || self.try("#{attrib}_changed?")
            end
          )

          # If the password was changed, force is_dirty to be true
          is_dirty = true if auth0_user_password_changed?

          # If the email was changed, force is_dirty to be true
          is_dirty = true if auth0_user_email_changed?

          return is_dirty
        end # auth0_dirty?


        def save_to_auth0
          # Determine if the user needs to be created or updated
          user_uid = auth0_user_uid

          if user_uid.nil? or user_uid.empty?
            found_user = users_in_auth0_with_matching_email.first

            user_uid = found_user['user_id'] if found_user
          end

          if user_uid.nil? or user_uid.empty?
            # The user has no auth0 uid assigned and we can't find a user
            # with a matching email address, so create.
            create_in_auth0
          else
            # The user already has an auth0 UID assigned or we have a user
            # with a matching email address, so update.
            update_in_auth0(user_uid)
          end
        end # save_to_auth0


        def create_in_auth0
          params = auth0_create_params

          response = SyncAttrWithAuth0::Auth0.create_user(auth0_user_name, params, config: auth0_sync_configuration)

          # Update the record with the uid after_commit
          @auth0_uid = response['user_id']
        end # create_in_auth0


        def update_in_auth0(user_uid)
          return unless user_uid

          params = auth0_update_params

          begin
            SyncAttrWithAuth0::Auth0.patch_user(user_uid, params, config: auth0_sync_configuration)

            # Update the record with the uid after_commit (in case it doesn't match what's on file).
            @auth0_uid = user_uid
          rescue ::Auth0::NotFound => e
            # For whatever reason, the passed in uid was invalid,
            # determine how to proceed.
            found_user = users_in_auth0_with_matching_email.first

            if found_user.nil?
              # We could not find a user with that email address, so create
              # instead.
              create_in_auth0
            else
              # The uid was incorrect, so re-attempt with the new uid
              # and update the one on file.
              SyncAttrWithAuth0::Auth0.patch_user(found_user['user_id'], params, config: auth0_sync_configuration)

              # Update the record with the uid after_commit
              @auth0_uid = found_user['user_id']
            end

          rescue Exception => e
            ::Rails.logger.error e.message
            ::Rails.logger.error e.backtrace.join("\n")

            raise e
          end
        end # update_in_auth0


        def auth0_create_params
          user_metadata = auth0_user_metadata
          app_metadata = auth0_app_metadata

          password = auth0_user_password

          if password.nil? or password.empty?
            # We MUST include a password on create.
            password = auth0_default_password
          end

          email_verified = auth0_email_verified?

          params = {
            'email' => auth0_user_email,
            'password' => password,
            'connection' => auth0_sync_configuration.connection_name,
            'email_verified' => email_verified,
            'user_metadata' => user_metadata,
            'app_metadata' => app_metadata
          }

          return params
        end # auth0_create_params


        def auth0_update_params
          user_metadata = auth0_user_metadata
          app_metadata = auth0_app_metadata

          params = {
            'app_metadata' => app_metadata,
            'user_metadata' => user_metadata
          }

          if auth0_user_password_changed?
            # The password needs to be updated.
            params['password'] = auth0_user_password
            params['verify_password'] = auth0_verify_password?
          end

          if auth0_user_email_changed?
            # The email needs to be updated.
            params['email'] = auth0_user_email
            params['verify_email'] = auth0_email_verified?
          end

          return params
        end # auth0_update_params


        def update_uid_from_auth0
          if @auth0_uid
            self.sync_with_auth0_on_update = false if self.respond_to?(:sync_with_auth0_on_update=)
            self.send("#{auth0_sync_configuration.auth0_uid_attribute}=", @auth0_uid)

            # Nil the instance variable to prevent an infinite loop
            @auth0_uid = nil

            # Save!
            self.save
          end

          true # don't abort the callback chain
        end # update_uid_from_auth0

      end
    end
  end
end
