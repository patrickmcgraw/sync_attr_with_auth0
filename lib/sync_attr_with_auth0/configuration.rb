require 'active_support/core_ext/module/attribute_accessors'

module SyncAttrWithAuth0

  class << self
    attr_accessor :configuration
  end

  # Start a SyncAttrWithAuth0 configuration block in an initializer
  #
  # example: Provide a default UID for the applicaiton
  #   SyncAttrWithAuth0.configure do |config|
  #     config.auth0_uid_attribute = :auth0_uid
  #   end
  def self.configure
    yield configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.reset_configuration
    @configuration = Configuration.new
  end

  # SyncAttrWithAuth0 configuration class.
  # This is used by SyncAttrWithAuth0 to provide configuration settings.
  class Configuration
    attr_accessor :auth0_global_client_id, :auth0_global_client_secret,
      :auth0_client_id, :auth0_client_secret, :auth0_namespace,
      :auth0_uid_attribute, :name_attribute, :given_name_attribute,
      :family_name_attribute, :email_attribute, :password_attribute,
      :email_verified_attribute, :verify_password_attribute, :picture_attribute,
      :connection_name, :search_connections


    def initialize
      @auth0_global_client_id = ENV['AUTH0_GLOBAL_CLIENT_ID']
      @auth0_global_client_secret = ENV['AUTH0_GLOBAL_CLIENT_SECRET']
      @auth0_client_id = ENV['AUTH0_CLIENT_ID']
      @auth0_client_secret = ENV['AUTH0_CLIENT_SECRET']
      @auth0_namespace = ENV['AUTH0_NAMESPACE']

      @auth0_uid_attribute = :auth0_uid
      @name_attribute = :name
      @given_name_attribute = :given_name
      @family_name_attribute = :family_name
      @email_attribute = :email
      @password_attribute = :password
      @email_verified_attribute = :email_verified
      @verify_password_attribute = :verify_password
      @picture_attribute = :picture
      @connection_name = 'Username-Password-Authentication'
      @search_connections = []
    end
  end
end
