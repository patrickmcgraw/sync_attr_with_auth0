module SyncAttrWithAuth0
  module Auth0

    def self.get_access_token
      payload = {
        "client_id" =>        ENV['AUTH0_CLIENT_ID'],
        "client_secret" =>    ENV['AUTH0_CLIENT_SECRET'],
        "grant_type" =>       "client_credentials"
      }

      response = SyncAttrWithAuth0::Auth0.make_request(nil, 'post', '/oauth/token', payload)

      response = JSON.parse( response.to_s ) unless response.nil? or response.to_s.empty?

      response['access_token']
    end

    def self.make_request(access_token, method, path, payload=nil)
      args = [method, "https://#{ENV['AUTH0_DOMAIN']}#{path}"]

      # The post body wedges in between the request url
      # and the request headers for POST and PUT methods
      args << payload if payload

      if access_token
        args << { content_type: :json, authorization: "Bearer #{access_token}", accept: "application/json" }

      else
        args << { content_type: :json, accept: "application/json" }

      end

      # Handle variable length arg lists
      _response = RestClient.send(*args)
    end

  end
end
