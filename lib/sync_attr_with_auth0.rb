require 'sync_attr_with_auth0/auth0'
require 'sync_attr_with_auth0/model'

::ActiveRecord::Base.send :include, ::SyncAttrWithAuth0::Model
