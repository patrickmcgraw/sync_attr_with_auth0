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


        def save_to_auth0_after_create
          return true unless sync_with_auth0_on_create?

          save_to_auth0

          true # don't abort the callback chain
        end # save_to_auth0_after_create


        def save_to_auth0_after_update
          return true unless sync_with_auth0_on_update?
          return true unless auth0_saved_change_dirty?

          save_to_auth0

          true # don't abort the callback chain
        end # save_to_auth0_after_update


        def auth0_saved_change_dirty?
          is_dirty = auth0_attributes_to_sync.any? do |attrib|
            if respond_to? :"saved_change_to_#{attrib}?"
              # Prefer modern method
              public_send :"saved_change_to_#{attrib}?"
            elsif respond_to? :"#{attrib}_changed?"
              # Legacy method. Drop when no longer supporting <= Rails 5.1
              public_send :"#{attrib}_changed?"
            else
              # Specs currently verify attributes specified as needing synced
              # that are not defined not cause an error. I'm not sure why we
              # need this. Seems like a misconfiguration and we should blow
              # up. But to limit scope of change keeping with defined behavior.
              false
            end
          end

          # If the password was changed, force is_dirty to be true
          is_dirty = true if auth0_user_saved_change_to_password?

          # If the email was changed, force is_dirty to be true
          is_dirty = true if auth0_user_saved_change_to_email?

          return is_dirty
        end # auth0_saved_change_dirty?


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

          response = SyncAttrWithAuth0::Auth0.create_user(params, config: auth0_sync_configuration)

          # Update the record with the uid and picture after_commit
          @auth0_uid = response['user_id']
          @auth0_picture = response['picture']
        end # create_in_auth0


        def update_in_auth0(user_uid)
          return unless user_uid

          begin
            response = SyncAttrWithAuth0::Auth0.patch_user(user_uid, auth0_update_params(user_uid), config: auth0_sync_configuration)

            # Update the record with the uid after_commit (in case it doesn't match what's on file).
            @auth0_uid = user_uid
            @auth0_picture = response['picture']
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
              response = SyncAttrWithAuth0::Auth0.patch_user(found_user['user_id'], auth0_update_params(found_user['user_id']), config: auth0_sync_configuration)

              # Update the record with the uid after_commit
              @auth0_uid = found_user['user_id']
              @auth0_picture = response['picture']
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
            'name' => auth0_user_name,
            'nickname' => auth0_user_name,
            'given_name' => auth0_user_given_name,
            'family_name' => auth0_user_family_name,
            'user_metadata' => user_metadata,
            'app_metadata' => app_metadata
          }

          return params
        end # auth0_create_params


        def auth0_update_params(user_uid)
          user_metadata = auth0_user_metadata
          app_metadata = auth0_app_metadata
          is_auth0_connection_strategy = user_uid.start_with?("auth0|")

          params = {
            'app_metadata' => app_metadata,
            'user_metadata' => user_metadata
          }

          if is_auth0_connection_strategy
            # We can update the name attributes on Auth0 connection strategy only.
            params['name'] = auth0_user_name
            params['nickname'] = auth0_user_name
            params['given_name'] = auth0_user_given_name
            params['family_name'] = auth0_user_family_name
          end

          if auth0_user_saved_change_to_password?
            # The password needs to be updated.
            params['password'] = auth0_user_password
            params['verify_password'] = auth0_verify_password?
          end

          if auth0_user_saved_change_to_email?
            # The email needs to be updated.
            params['email'] = auth0_user_email
            params['verify_email'] = !auth0_email_verified?
          end

          return params
        end # auth0_update_params


        def update_uid_and_picture_from_auth0
          data = {}

          if @auth0_uid
            attr = auth0_sync_configuration.auth0_uid_attribute
            data[attr] = @auth0_uid if respond_to?(attr) && @auth0_uid != public_send(attr)
          end

          if @auth0_picture
            attr = auth0_sync_configuration.picture_attribute
            data[attr] = @auth0_picture if respond_to?(attr) && @auth0_picture != public_send(attr)
          end

          update_columns data unless data.empty?

          remove_instance_variable :@auth0_uid if defined? @auth0_uid
          remove_instance_variable :@auth0_picture if defined? @auth0_picture

          true # don't abort the callback chain
        end # update_uid_and_picture_from_auth0

      end
    end
  end
end
