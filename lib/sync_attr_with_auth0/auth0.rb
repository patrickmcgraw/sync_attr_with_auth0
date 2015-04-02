module SyncAttrWithAuth0
  module Auth0
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
    end

    def self.create_auth0_client(
      api_version: 2,
      global_client_id: ENV['AUTH0_GLOBAL_CLIENT_ID'],
      global_client_secret: ENV['AUTH0_GLOBAL_CLIENT_SECRET'],
      client_id: ENV['AUTH0_CLIENT_ID'],
      client_secret: ENV['AUTH0_CLIENT_SECRET'],
      namespace: ENV['AUTH0_DOMAIN']
    )
      case api_version
      when 1
        auth0 = Auth0Client.new(client_id: client_id, client_secret: client_secret, namespace: namespace)
      when 2
        jwt = SyncAttrWithAuth0::Auth0.create_auth0_jwt(global_client_id: global_client_id, global_client_secret: global_client_secret)
        auth0 = Auth0Client.new(api_version: 2, access_token: jwt, namespace: namespace)
      end

      return auth0
    end

  end
end
