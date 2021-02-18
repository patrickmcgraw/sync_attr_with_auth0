RSpec.describe SyncAttrWithAuth0::Auth0 do

  require 'jwt'

  describe "::create_auth0_jwt" do
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
      expect(UUIDTools::UUID).to receive(:random_create).and_return('uuid')
      expect(JWT::Base64).to receive(:url_decode).with('global client secret').and_return('decoded global client secret')
      expect(JWT).to receive(:encode).with(mock_payload, 'decoded global client secret', 'HS256', { typ: 'JWT' }).and_return('jwt string')
    end

    it "should create and return a java web token for auth0" do
      expect(::SyncAttrWithAuth0::Auth0.create_auth0_jwt(global_client_id: 'global client id', global_client_secret: 'global client secret')).to eq('jwt string')
    end
  end # ::create_auth0_jwt


  describe "::create_auth0_client" do
    let(:mock_config) do
      double(
        Object,
        {
          auth0_global_client_id: 'global client id',
          auth0_global_client_secret: 'global client secret',
          auth0_client_id: 'client id',
          auth0_client_secret: 'client secret',
          auth0_namespace: 'namespace'
        }
      )
    end

    before { allow(SyncAttrWithAuth0).to receive(:configuration).and_return(mock_config) }

    context "when api_version is 1" do
      before { expect(Auth0Client).to receive(:new).with(client_id: 'client id', client_secret: 'client secret', namespace: 'namespace').and_return('version 1 api client') }

      it "should return a client for version 1 of the API" do
        expect(::SyncAttrWithAuth0::Auth0.create_auth0_client(api_version: 1)).to eq('version 1 api client')
      end
    end

    context "when api_version is 2" do
      before do
        expect(::SyncAttrWithAuth0::Auth0).to receive(:create_auth0_jwt).with(global_client_id: 'global client id', global_client_secret: 'global client secret').and_return('jwt string')
        expect(Auth0Client).to receive(:new).with(api_version: 2, access_token: 'jwt string', namespace: 'namespace').and_return('version 2 api client')
      end

      it "should return a client for version 2 of the API" do
        expect(::SyncAttrWithAuth0::Auth0.create_auth0_client).to eq('version 2 api client')
      end
    end
  end # ::create_auth0_client


  describe "::validate_auth0_config_for_api" do
    let(:mock_config) do
      double(
        Object,
        {
          auth0_global_client_id: nil,
          auth0_global_client_secret: nil,
          auth0_client_id: nil,
          auth0_client_secret: nil,
          auth0_namespace: nil
        }
      )
    end

    before { allow(SyncAttrWithAuth0).to receive(:configuration).and_return(mock_config) }

    context "when the api version is 1" do
      it "should raise an exception listing the v1 missing settings" do
        expect {
          ::SyncAttrWithAuth0::Auth0.validate_auth0_config_for_api(1)
        }.to raise_error(::SyncAttrWithAuth0::Auth0::InvalidAuth0ConfigurationException, "The following required auth0 settings were invalid: auth0_client_id, auth0_client_secret, auth0_namespace")
      end
    end

    context "when the api version is 2" do
      it "should raise an exception listing the v2 missing settings" do
        expect {
          ::SyncAttrWithAuth0::Auth0.validate_auth0_config_for_api(2)
        }.to raise_error(::SyncAttrWithAuth0::Auth0::InvalidAuth0ConfigurationException, "The following required auth0 settings were invalid: auth0_global_client_id, auth0_global_client_secret, auth0_namespace")
      end
    end
  end # ::validate_auth0_config_for_api


  describe "::find_users_by_email" do
    let(:email) { 'foo@email.com' }
    let(:mock_config) do
      double(
        Object,
        {
          auth0_global_client_id: 'global client id',
          auth0_global_client_secret: 'global client secret',
          auth0_client_id: 'client id',
          auth0_client_secret: 'client secret',
          auth0_namespace: 'namespace',
          search_connections: [],
        }
      )
    end
    let(:mock_client) { double(Object) }
    let(:mock_result1) { { 'email' => 'foo@email.com', 'user_id' => 'a user id' } }
    let(:mock_result2) { { 'email' => 'foo@email.com', 'user_id' => 'not a user id' } }
    let(:mock_results) { [mock_result1, mock_result2] }

    before do
      allow(SyncAttrWithAuth0).to receive(:configuration).and_return(mock_config)
      allow(SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).with(config: mock_config).and_return(mock_client)

    end

    context 'without specified search connections' do
      before do
        allow(mock_client).to receive(:get).with('/api/v2/users', q: "email:foo@email.com", search_engine: 'v3').and_return(mock_results)
      end

      context "when a user id is passed in to filter" do
        it "should return the results from the auth0 search" do
          expect(SyncAttrWithAuth0::Auth0.find_users_by_email(email, exclude_user_id: 'a user id')).to eq([mock_result2])
        end
      end

      context "when a user id is not passed in to filter" do
        it "should return the results from the auth0 search" do
          expect(SyncAttrWithAuth0::Auth0.find_users_by_email(email)).to eq(mock_results)
        end
      end
    end

    context 'with specified search connections' do
      before do
        mock_config.search_connections << 'User-DB-1' << 'User-DB-2'
        allow(mock_client).to receive(:get).with('/api/v2/users', q: %Q{email:foo@email.com AND (identities.connection:"User-DB-1" OR identities.connection:"User-DB-2")}, search_engine: 'v3').and_return(mock_results)
      end

      it 'should add connections to criteria' do
        expect(SyncAttrWithAuth0::Auth0.find_users_by_email(email)).to eq(mock_results)
      end
    end
  end # ::find_users_by_email


  describe "::create_user" do
    let(:name) { 'John Doe' }
    let(:params) do
      { 'connection' => 'Username-Password-Authentication' }
    end
    let(:mock_config) do
      double(
        Object,
        {
          auth0_global_client_id: 'global client id',
          auth0_global_client_secret: 'global client secret',
          auth0_client_id: 'client id',
          auth0_client_secret: 'client secret',
          auth0_namespace: 'namespace',
        }
      )
    end
    let(:mock_client) { double(Object) }

    before do
      allow(SyncAttrWithAuth0).to receive(:configuration).and_return(mock_config)
      allow(SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).with(config: mock_config).and_return(mock_client)
      allow(mock_client).to receive(:create_user).with('Username-Password-Authentication', {}).and_return('response!')
    end

    it "should return the response from posting to auth0" do
      expect(SyncAttrWithAuth0::Auth0.create_user(params)).to eq('response!')
    end
  end # ::create_user


  describe "::patch_user" do
    let(:uid) { 'uid' }
    let(:params) do
      {}
    end
    let(:mock_config) do
      double(
        Object,
        {
          auth0_global_client_id: 'global client id',
          auth0_global_client_secret: 'global client secret',
          auth0_client_id: 'client id',
          auth0_client_secret: 'client secret',
          auth0_namespace: 'namespace'
        }
      )
    end
    let(:mock_client) { double(Object) }

    before do
      allow(SyncAttrWithAuth0).to receive(:configuration).and_return(mock_config)
      allow(SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).with(config: mock_config).and_return(mock_client)
      allow(mock_client).to receive(:patch_user).with('uid', {}).and_return('response!')
    end

    it "should return the response from posting to auth0" do
      expect(SyncAttrWithAuth0::Auth0.patch_user(uid, params)).to eq('response!')
    end
  end # ::patch_user

end
