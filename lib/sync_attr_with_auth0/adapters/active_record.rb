require 'sync_attr_with_auth0/adapters/active_record/validation'
require 'sync_attr_with_auth0/adapters/active_record/auth0_sync'

module SyncAttrWithAuth0
  module Adapters
    module ActiveRecord
      extend ::ActiveSupport::Concern

      include SyncAttrWithAuth0::Adapters::ActiveRecord::Validation
      include SyncAttrWithAuth0::Adapters::ActiveRecord::Auth0Sync

      require "uuidtools"

      module ClassMethods

        def sync_attr_with_auth0(*fields)
          options = fields.extract_options!

          # Setup methods for accessing fields and options
          define_method 'auth0_attributes_to_sync' do
            fields
          end

          define_method 'setup_auth0_sync_configuration' do
            config = SyncAttrWithAuth0.configuration.dup

            options.each do |key, value|
              config.send(:"#{key}=", value)
            end

            config
          end

          # Setup callbacks
          after_validation :validate_email_with_auth0
          after_create :save_to_auth0_after_create
          after_update :save_to_auth0_after_update
          after_commit :update_uid_from_auth0
        end # sync_attr_with_auth0

      end # ClassMethods


      def auth0_sync_configuration
        @auth0_sync_configuration ||= setup_auth0_sync_configuration
      end # auth0_sync_configuration

    private

      def auth0_user_email
        self.send(auth0_sync_configuration.email_attribute) if self.respond_to?(auth0_sync_configuration.email_attribute)
      end # auth0_user_email


      def auth0_user_saved_change_to_email?
        return false unless self.respond_to?(auth0_sync_configuration.email_attribute)
        # return false unless sync_email_with_auth0? # We don't care if it changed if we aren't syncing it.

        if respond_to? :"saved_change_to_#{auth0_sync_configuration.email_attribute}?"
          # Modern method
          public_send :"saved_change_to_#{auth0_sync_configuration.email_attribute}?"
        else
          # Legacy method. Drop when no longer supporting <= Rails 5.1
          public_send :"#{auth0_sync_configuration.email_attribute}_changed?"
        end
      end # auth0_user_saved_change_to_email?


      def auth0_user_uid
        self.send(auth0_sync_configuration.auth0_uid_attribute) if self.respond_to?(auth0_sync_configuration.auth0_uid_attribute)
      end # auth0_user_uid


      def auth0_user_name
        self.send(auth0_sync_configuration.name_attribute) if self.respond_to?(auth0_sync_configuration.name_attribute)
      end # auth0_user_name


      def auth0_user_given_name
        self.send(auth0_sync_configuration.given_name_attribute) if self.respond_to?(auth0_sync_configuration.given_name_attribute)
      end # auth0_user_name


      def auth0_user_family_name
        self.send(auth0_sync_configuration.family_name_attribute) if self.respond_to?(auth0_sync_configuration.family_name_attribute)
      end # auth0_user_name


      def auth0_user_password
        self.send(auth0_sync_configuration.password_attribute) if self.respond_to?(auth0_sync_configuration.password_attribute)
      end # auth0_user_password


      def auth0_user_saved_change_to_password?
        return false unless self.respond_to?(auth0_sync_configuration.password_attribute)

        case
          when respond_to?(:"saved_change_to_#{auth0_sync_configuration.password_attribute}?")
            # Prefer modern method
            public_send :"saved_change_to_#{auth0_sync_configuration.password_attribute}?"
          when respond_to?(:"#{auth0_sync_configuration.password_attribute}_changed?")
            # Legacy method. Drop when no longer supporting <= Rails 5.1
            public_send :"#{auth0_sync_configuration.password_attribute}_changed?"
          else
            # Neither exists so must be in-memory accessor. Just check if set.
            public_send(auth0_sync_configuration.password_attribute).present?
        end
      end # auth0_user_saved_change_to_password?


      def auth0_default_password
        # Need a9 or something similar to guarantee one letter and one number in the password
        "#{auth0_new_uuid[0..19]}aA9"
      end # auth0_default_password


      def auth0_new_uuid
        ::UUIDTools::UUID.random_create().to_s
      end # auth0_new_uuid


      def auth0_email_verified?
        # Unless we're explicitly told otherwise, don't consider the email verified.
        return false unless self.respond_to?(auth0_sync_configuration.email_verified_attribute)

        return self.send(auth0_sync_configuration.email_verified_attribute)
      end # auth0_email_verified?


      def auth0_verify_password?
        # Unless we're explicitly told otherwise, verify the password changes.
        return true unless self.respond_to?(auth0_sync_configuration.verify_password_attribute)

        self.send(auth0_sync_configuration.verify_password_attribute)
      end # auth0_verify_password?


      def auth0_user_metadata
        user_metadata = {}

        non_metadata_keys = [
          auth0_sync_configuration.name_attribute,
          auth0_sync_configuration.family_name_attribute,
          auth0_sync_configuration.given_name_attribute,
          auth0_sync_configuration.email_attribute,
          auth0_sync_configuration.password_attribute,
          auth0_sync_configuration.email_verified_attribute
        ]

        auth0_attributes_to_sync.each do |key|
          user_metadata[key.to_s] = self.send(key) if self.respond_to?(key) and non_metadata_keys.index(key).nil?
        end

        return user_metadata
      end # auth0_user_metadata


      def auth0_app_metadata
        return {
          'name' => auth0_user_name,
          'nickname' => auth0_user_name,
          'given_name' => auth0_user_given_name,
          'family_name' => auth0_user_family_name
        }
      end # auth0_app_metadata


    end
  end
end
