RSpec.describe SyncAttrWithAuth0::Auth0 do

  require 'jwt'

  describe "#create_auth0_jwt" do
    let(:mock_payload) do
      {
        'aud' => 'global client id',
        'scopes' => {
          'users' => {
            'actions' => ['create', 'update', 'read']
          }
        },
        'iat' => 1,
        'jti' => 'uuid'
      }
    end

    before do
      expect(Time).to receive(:now).and_return(1)
      expect(UUIDTools::UUID).to receive(:timestamp_create).and_return('uuid')
      expect(JWT).to receive(:base64url_decode).with('global client secret').and_return('decoded global client secret')
      expect(JWT).to receive(:encode).with(mock_payload, 'decoded global client secret').and_return('jwt string')
    end

    it "should create and return a java web token for auth0" do
      expect(::SyncAttrWithAuth0::Auth0.create_auth0_jwt(global_client_id: 'global client id', global_client_secret: 'global client secret')).to eq('jwt string')
    end
  end

  describe "#create_auth0_client" do
    context "when api_version is 1" do
      before { expect(Auth0Client).to receive(:new).with(client_id: 'client id', client_secret: 'client secret', namespace: 'namespace').and_return('version 1 api client') }

      it "should return a client for version 1 of the API" do
        expect(::SyncAttrWithAuth0::Auth0.create_auth0_client(
          api_version: 1,
          global_client_id: 'global client id',
          global_client_secret: 'global client secret',
          client_id: 'client id',
          client_secret: 'client secret',
          namespace: 'namespace'
        )).to eq('version 1 api client')
      end
    end

    context "when api_version is 2" do
      before do
        expect(::SyncAttrWithAuth0::Auth0).to receive(:create_auth0_jwt).with(global_client_id: 'global client id', global_client_secret: 'global client secret').and_return('jwt string')
        expect(Auth0Client).to receive(:new).with(api_version: 2, access_token: 'jwt string', namespace: 'namespace').and_return('version 2 api client')
      end

      it "should return a client for version 1 of the API" do
        expect(::SyncAttrWithAuth0::Auth0.create_auth0_client(
          api_version: 2,
          global_client_id: 'global client id',
          global_client_secret: 'global client secret',
          client_id: 'client id',
          client_secret: 'client secret',
          namespace: 'namespace'
        )).to eq('version 2 api client')
      end
    end
  end

end
