module SyncAttrWithAuth0
  module Model
    extend ::ActiveSupport::Concern

    included do
      after_save :sync_attr_with_auth0
    end

    module ClassMethods
      def sync_attr_with_auth0(*args)
        class_attribute :auth0_uid_att
        class_attribute :auth0_sync_atts

        self.auth0_uid_att = args.shift

        self.auth0_sync_atts ||= []
        self.auth0_sync_atts += args.shift.collect(&:to_s)

        after_save :sync_attr_with_auth0
      end
    end

    def sync_attr_with_auth0
      # Look for matches between what's changing
      # and what needs to be transmitted to Auth0
      matches = ( (self.class.auth0_sync_atts || []) & (self.changes.keys || []) )

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
          response = SyncAttrWithAuth0::Auth0.make_request(
            access_token,
            'patch',
            "/api/users/#{::URI.escape( self.send(auth0_uid_att) )}/metadata",
            changes)
        end
      end

      true # don't abort the callback chain
    end

  end
end
