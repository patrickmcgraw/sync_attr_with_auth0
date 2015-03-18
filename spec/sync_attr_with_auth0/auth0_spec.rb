RSpec.describe SyncAttrWithAuth0::Auth0 do

  describe "::get_access_token" do
    it "returns the access_token from make_request" do
      expect(::SyncAttrWithAuth0::Auth0).to receive(:make_request).with(
        nil,
        'post',
        '/oauth/token',
        {
          "client_id" =>        'auth0_client_id_123',
          "client_secret" =>    'auth0_client_secret_456',
          "grant_type" =>       "client_credentials"
        }).and_return({'access_token' => 'the-access-token'}.to_json)

      expect(::SyncAttrWithAuth0::Auth0.get_access_token).to eql('the-access-token')
    end
  end

  describe "::make_request" do

    context "when an access token is passed in" do
      it "makes an HTTP request with an authorization header" do
        expect(::RestClient).to receive(:send).with(
          'post',
          'https://auth0.domain.com/request/path',
          'some payload',
          { content_type: :json, authorization: "Bearer access_token_37", accept: "application/json" }
        )

        ::SyncAttrWithAuth0::Auth0.make_request 'access_token_37', 'post', '/request/path', 'some payload'
      end
    end

    context "when an access token is not passed in" do
      it "makes an HTTP request without an authorization header" do
        expect(::RestClient).to receive(:send).with(
          'post',
          'https://auth0.domain.com/request/path',
          'some payload',
          { content_type: :json, accept: "application/json" }
        )

        ::SyncAttrWithAuth0::Auth0.make_request nil, 'post', '/request/path', 'some payload'
      end
    end

  end

end
