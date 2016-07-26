require 'sync_attr_with_auth0/auth0'
# require 'sync_attr_with_auth0/model'
require 'sync_attr_with_auth0/configuration'
require 'sync_attr_with_auth0/adapters/active_record'

module SyncAttrWithAuth0
  ::ActiveRecord::Base.send :include, ::SyncAttrWithAuth0::Adapters::ActiveRecord
end
