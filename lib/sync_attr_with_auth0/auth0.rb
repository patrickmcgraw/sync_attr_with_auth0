module SyncAttrWithAuth0
  module Auth0
    class InvalidAuth0ConfigurationException < StandardError; end

    require "auth0"
    require "uuidtools"

    def self.create_auth0_jwt(global_client_id: ENV['AUTH0_GLOBAL_CLIENT_ID'], global_client_secret: ENV['AUTH0_GLOBAL_CLIENT_SECRET'])
      payload = {
        'aud' => global_client_id,
        'scopes' => {
          'users' => {
            'actions' => ['create', 'update', 'read']
          }
        },
        'iat' => Time.now.to_i,
        'jti' => UUIDTools::UUID.timestamp_create.to_s
      }

      jwt = JWT.encode(payload, JWT.base64url_decode(global_client_secret))

      return jwt
    end # ::create_auth0_jwt


    def self.create_auth0_client(
      api_version: 2,
      config: SyncAttrWithAuth0.configuration
    )
      validate_auth0_config_for_api(api_version, config: config)

      case api_version
      when 1
        auth0 = Auth0Client.new(client_id: config.auth0_client_id, client_secret: config.auth0_client_secret, namespace: config.auth0_namespace)
      when 2
        jwt = SyncAttrWithAuth0::Auth0.create_auth0_jwt(global_client_id: config.auth0_global_client_id, global_client_secret: config.auth0_global_client_secret)
        auth0 = Auth0Client.new(api_version: 2, access_token: jwt, namespace: config.auth0_namespace)
      end

      return auth0
    end # ::create_auth0_client


    def self.validate_auth0_config_for_api(api_version, config: SyncAttrWithAuth0.configuration)
      settings_to_validate = []
      invalid_settings = []

      case api_version
      when 1
        settings_to_validate = [:auth0_client_id, :auth0_client_secret, :auth0_namespace]
      when 2
        settings_to_validate = [:auth0_global_client_id, :auth0_global_client_secret, :auth0_namespace]
      end

      settings_to_validate.each do |setting_name|
        unless config.send(setting_name)
          invalid_settings << setting_name
        end
      end

      if invalid_settings.length > 0
        raise InvalidAuth0ConfigurationException.new("The following required auth0 settings were invalid: #{invalid_settings.join(', ')}")
      end
    end # ::validate_auth0_config_for_api


    def self.find_users_by_email(email, exclude_user_id: nil, config: SyncAttrWithAuth0.configuration)
      auth0 = SyncAttrWithAuth0::Auth0.create_auth0_client(config: config)

      # Use the Lucene search because Find by Email is case sensitive
      query = "email:#{email}"
      unless config.search_connections.empty?
        conn_query = config.search_connections
          .collect { |conn| %Q{identities.connection:"#{conn}"} }
          .join ' OR '
        query = "#{query} AND (#{conn_query})"
      end

      results = auth0.get('/api/v2/users', q: query, search_engine: 'v3')

      if exclude_user_id
        results = results.reject { |r| r['user_id'] == exclude_user_id }
      end

      return results
    end # ::find_users_by_email


    def self.create_user(name, params, config: SyncAttrWithAuth0.configuration)
      auth0 = SyncAttrWithAuth0::Auth0.create_auth0_client(config: config)

      return auth0.create_user(name, params)
    end # ::create_user


    def self.patch_user(uid, params, config: SyncAttrWithAuth0.configuration)
      auth0 = SyncAttrWithAuth0::Auth0.create_auth0_client(config: config)

      return auth0.patch_user(uid, params)
    end # ::patch_user

  end
end
