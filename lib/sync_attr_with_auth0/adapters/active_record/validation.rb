module SyncAttrWithAuth0
  module Adapters
    module ActiveRecord
      module Validation

        def validate_with_auth0?
          !!((self.respond_to?(:validate_with_auth0) and !self.validate_with_auth0.nil?) ? self.validate_with_auth0 : true)
        end # validate_with_auth0?


        def validate_email_with_auth0?
          email_changed_method_name = "#{auth0_sync_configuration.email_attribute.to_s}_changed?"

          !!(validate_with_auth0? and self.send(email_changed_method_name))
        end # validate_email_with_auth0?


        def validate_email_with_auth0
          return true unless validate_email_with_auth0?

          return users_in_auth0_with_matching_email.empty?
        end # validate_email_with_auth0

        def users_in_auth0_with_matching_email
          return SyncAttrWithAuth0::Auth0.find_users_by_email(auth0_user_email, auth0_sync_configuration)
        end # users_in_auth0_with_matching_email

      end
    end
  end
end
