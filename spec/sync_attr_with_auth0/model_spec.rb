RSpec.describe SyncAttrWithAuth0::Model do

  describe "ActiveRecord::Base" do
    it "responds to ::sync_attr_with_auth0" do
      expect(ActiveRecord::Base.respond_to?(:sync_attr_with_auth0)).to eql(true)
    end
  end

  class TestModel
    include SyncAttrWithAuth0::Model

    class_attribute :_after_validation
    self._after_validation = []
    def self.after_validation(callback)
      self._after_validation << callback
    end

    class_attribute :_after_create
    self._after_create = []
    def self.after_create(callback)
      self._after_create << callback
    end

    class_attribute :_after_update
    self._after_update = []
    def self.after_update(callback)
      self._after_update << callback
    end

    def changes; end;
    def email_changed?; end;
    def save; end;

    def name; end;
    def uid; end;
    def uid=(uid); end;
    def email; end;

    def validate_with_auth0; return true; end;
    def sync_with_auth0_on_create; return true; end;
    def sync_with_auth0_on_update; return true; end;

    sync_attr_with_auth0 auth0_sync_atts: [:name, :email, :password, :undefined_attribute]
  end

  class TestModelWithoutPassword < TestModel
    def email_verified; end;

    # sync_attr_with_auth0 sync_atts: [:name, :email]
  end

  class TestModelWithoutEmailVerified < TestModel
    def password; end;

    # sync_attr_with_auth0 sync_atts: [:name, :email]
  end

  class FullTestModel < TestModel
    def password; end;
    def email_verified; end;

    # sync_attr_with_auth0 sync_atts: [:name, :email, :password]
  end

  let(:test_model) { FullTestModel.new }

  it "has #sync_attr_with_auth0 as an after_validation callback" do
    expect(FullTestModel._after_validation).to eql([:validate_email_with_auth0])
  end

  it "has #sync_attr_with_auth0 as an after_create callback" do
    expect(FullTestModel._after_create).to eql([:create_user_in_auth0])
  end

  it "has #sync_attr_with_auth0 as an after_update callback" do
    expect(FullTestModel._after_update).to eql([:sync_attr_with_auth0])
  end

  it "responds to #sync_attr_with_auth0" do
    expect(test_model.respond_to?(:sync_attr_with_auth0)).to eql(true)
  end

  describe "#validate_email_with_auth0" do

    context "when suppressing validation" do
      before { expect(test_model).to receive(:validate_with_auth0).at_least(1).and_return(false) }

      it "returns true" do
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:get_access_token)

        expect(test_model.validate_email_with_auth0).to eql(true)
      end
    end

    context "when the email is not being changed" do
      before { expect(test_model).to receive(:email_changed?).and_return(false) }

      it "returns true" do
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:get_access_token)

        expect(test_model.validate_email_with_auth0).to eql(true)
      end
    end

    context "when the email is being changed" do
      before do
        expect(test_model).to receive(:email_changed?).and_return(true)
        expect(::SyncAttrWithAuth0::Auth0).to receive(:get_access_token).and_return('some access token')
        expect(test_model).to receive(:email).and_return('bar@email.com')
      end

      context "when the new email does not exist in auth0" do
        it "should return true" do
          expect(::SyncAttrWithAuth0::Auth0).to receive(:make_request).with(
            'some access token',
            'get',
            '/api/users?search=email:bar@email.com'
          ).and_return('[]')

          expect(test_model.validate_email_with_auth0).to eql(true)
        end
      end

      context "when the new email does exist in auth0" do
        it "should return false" do
          expect(::SyncAttrWithAuth0::Auth0).to receive(:make_request).with(
            'some access token',
            'get',
            '/api/users?search=email:bar@email.com'
          ).and_return('["some results!"]')

          expect(test_model.validate_email_with_auth0).to eql(false)
        end
      end
    end

  end


  describe "#create_user_in_auth0" do
    context "when suppressing sync on create" do
      before { expect(test_model).to receive(:sync_with_auth0_on_create).at_least(1).and_return(false) }

      it "returns true" do
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:get_access_token)

        expect(test_model.create_user_in_auth0).to eql(true)
      end
    end

    context "when the user already has a uid" do
      before { expect(test_model).to receive(:uid).at_least(1).and_return('Some User ID') }

      it "returns true" do
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:get_access_token)

        expect(test_model.create_user_in_auth0).to eql(true)
      end
    end

    context "when not suppressing sync on create" do
      before do
        expect(::SyncAttrWithAuth0::Auth0).to receive(:get_access_token).and_return('some access token')
        expect(test_model).to receive(:changes).and_return( {'name' => [nil, 'is'], 'email' => [nil, 'foo@email.com'], 'password' => [nil, 'some password']} )
        expect(test_model).to receive(:name).and_return('new name')
        expect(test_model).to receive(:email).twice.and_return('foo@email.com')
      end

      context "when password and email_verified are defined on the model" do
        let(:mock_user_data) do
          {
            'email' => 'foo@email.com',
            'password' => 'some password',
            'connection' => 'Username-Password-Authentication',
            'email_verified' => true,
            'name' => 'new name'
          }
        end

        before do
          expect(test_model).to receive(:password).twice.and_return('some password')
          expect(test_model).to receive(:email_verified).and_return(true)
        end

        it "should add the user to auth0 and update the local user with the auth0 user id" do
          # Do Nothing (test performed by after block)
        end
      end

      context "when password is not defined on the model" do
        let(:mock_user_data) do
          {
            'email' => 'foo@email.com',
            'password' => 'default password',
            'connection' => 'Username-Password-Authentication',
            'email_verified' => true,
            'name' => 'new name'
          }
        end
        let(:test_model) { TestModelWithoutPassword.new }

        before do
          expect(test_model).to receive(:email_verified).and_return(true)
          expect(test_model).to receive(:auth0_default_password).and_return('default password')
        end

        it "should add the user to auth0 with a default password and update the local user with the auth0 user id" do
          # Do Nothing (test performed by after block)
        end
      end

      context "when email_verified is not defined on the model" do
        let(:mock_user_data) do
          {
            'email' => 'foo@email.com',
            'password' => 'some password',
            'connection' => 'Username-Password-Authentication',
            'email_verified' => false,
            'name' => 'new name'
          }
        end
        let(:test_model) { TestModelWithoutEmailVerified.new }

        before do
          expect(test_model).to receive(:password).twice.and_return('some password')
        end

        it "should add the user to auth0 with a default email_verified and update the local user with the auth0 user id" do
          # Do Nothing (test performed by after block)
        end
      end

      after do
        expect(::SyncAttrWithAuth0::Auth0).to receive(:make_request).with(
          'some access token',
          'post',
          '/api/users',
          mock_user_data
        ).and_return('{"user_id":"auth0|user_id"}')

        expect(test_model).to receive(:uid=).with('auth0|user_id')
        expect(test_model).to receive(:save).and_return(true)

        expect(test_model.create_user_in_auth0).to eq(true)
      end
    end
  end


  describe "#sync_attr_with_auth0" do

    context "when suppressing sync on update" do
      before { expect(test_model).to receive(:sync_with_auth0_on_update).at_least(1).and_return(false) }

      it "returns true" do
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:get_access_token)

        expect(test_model.sync_attr_with_auth0).to eql(true)
      end
    end

    context "when there are no changes" do
      before { expect(test_model).to receive(:changes).and_return( {'not_name' => ['was', 'is']} ) }

      it "does nothing" do
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:get_access_token)

        expect(test_model.sync_attr_with_auth0).to eql(true)
      end
    end

    context "when there are changes" do
      before { expect(test_model).to receive(:changes).and_return( {'name' => ['was', 'is']} ) }

      it "does nothing" do
        expect(::SyncAttrWithAuth0::Auth0).to receive(:get_access_token).and_return('some access token')
        expect(test_model).to receive(:name).and_return('new name')
        expect(test_model).to receive(:uid).and_return('the uid')

        expect(::SyncAttrWithAuth0::Auth0).to receive(:make_request).with(
          'some access token',
          'patch',
          '/api/users/the%20uid/metadata',
          { 'name' => 'new name' }
        )

        expect(test_model.sync_attr_with_auth0).to eql(true)
      end
    end

    context "when the email is also changed" do
      before { expect(test_model).to receive(:changes).and_return( {'name' => ['was', 'is'], 'email' => ['was', 'is']} ) }

      it "does nothing" do
        expect(::SyncAttrWithAuth0::Auth0).to receive(:get_access_token).and_return('some access token')
        expect(test_model).to receive(:name).and_return('new name')
        expect(test_model).to receive(:email).and_return('new email')
        expect(test_model).to receive(:uid).and_return('the uid')

        expect(::SyncAttrWithAuth0::Auth0).to receive(:make_request).with(
          'some access token',
          'put',
          '/api/users/the%20uid/email',
          { 'email' => 'new email', 'verify' => false }
        ).and_return('{"user_id":"auth0|user_id"}')

        expect(test_model).to receive(:uid=).with('auth0|user_id')
        expect(test_model).to receive(:save).and_return(true)

        expect(::SyncAttrWithAuth0::Auth0).to receive(:make_request).with(
          'some access token',
          'patch',
          '/api/users/the%20uid/metadata',
          { 'name' => 'new name' }
        )

        expect(test_model.sync_attr_with_auth0).to eql(true)
      end
    end

    context "when the password is changed" do
      before { expect(test_model).to receive(:changes).and_return( {'name' => ['was', 'is'], 'password' => ['was', 'is']} ) }

      it "does nothing" do
        expect(::SyncAttrWithAuth0::Auth0).to receive(:get_access_token).and_return('some access token')
        expect(test_model).to receive(:name).and_return('new name')
        expect(test_model).to receive(:password).and_return('new password')
        expect(test_model).to receive(:uid).and_return('the uid')

        expect(::SyncAttrWithAuth0::Auth0).to receive(:make_request).with(
          'some access token',
          'put',
          '/api/users/the%20uid/password',
          { 'password' => 'new password', 'verify' => true }
        )

        expect(::SyncAttrWithAuth0::Auth0).to receive(:make_request).with(
          'some access token',
          'patch',
          '/api/users/the%20uid/metadata',
          { 'name' => 'new name' }
        )

        expect(test_model.sync_attr_with_auth0).to eql(true)
      end
    end

  end


end
