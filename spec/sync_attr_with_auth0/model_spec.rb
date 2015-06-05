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
    def password_changed?; end;
    def save; end;

    def name; end;
    def given_name; end;
    def family_name; end;
    def uid; end;
    def uid=(uid); end;
    def email; end;
    def foo; end;

    def validate_with_auth0; return true; end;
    def sync_with_auth0_on_create; return true; end;
    def sync_with_auth0_on_update; return true; end;

    sync_attr_with_auth0 sync_atts: [:name, :email, :password, :foo, :undefined_attribute]
  end

  class TestModelWithoutPassword < TestModel
    def email_verified; end;
  end

  class TestModelWithoutEmailVerified < TestModel
    def password; end;
  end

  class FullTestModel < TestModel
    def password; end;
    def email_verified; end;
    def verify_password; end;
  end

  let(:test_model) { FullTestModel.new }
  let (:mock_auth0_client) { double(Object) }

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
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:create_auth0_client)

        expect(test_model.validate_email_with_auth0).to eql(true)
      end
    end

    context "when the email is not being changed" do
      before { expect(test_model).to receive(:email_changed?).and_return(false) }

      it "returns true" do
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:create_auth0_client)

        expect(test_model.validate_email_with_auth0).to eql(true)
      end
    end

    context "when the email is being changed" do
      before do
        expect(test_model).to receive(:email_changed?).and_return(true)
        expect(::SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).and_return(mock_auth0_client)
        expect(test_model).to receive(:email).and_return('bar@email.com')
      end

      context "when the new email does not exist in auth0" do
        it "should return true" do
          expect(mock_auth0_client).to receive(:users).with('email:bar@email.com').and_return([])

          expect(test_model.validate_email_with_auth0).to eql(true)
        end
      end

      context "when the new email does exist in auth0" do
        it "should return false" do
          expect(mock_auth0_client).to receive(:users).with('email:bar@email.com').and_return(['a result!'])

          expect(test_model.validate_email_with_auth0).to eql(false)
        end
      end
    end

  end

  describe "#create_user_in_auth0" do
    context "when suppressing sync on create" do
      before { expect(test_model).to receive(:sync_with_auth0_on_create).at_least(1).and_return(false) }

      it "returns true" do
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:create_auth0_client)

        expect(test_model.create_user_in_auth0).to eql(true)
      end
    end

    context "when the user already has a uid" do
      before { expect(test_model).to receive(:uid).at_least(1).and_return('Some User ID') }

      it "returns true" do
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:create_auth0_client)

        expect(test_model.create_user_in_auth0).to eql(true)
      end
    end

    context "when not suppressing sync on create" do
      before do
        expect(test_model).to receive(:auth0_user_metadata).and_return( {'foo' => 'bar'} )
        expect(test_model).to receive(:name).and_return('new name')
        expect(test_model).to receive(:email).and_return('foo@email.com')
      end

      context "when password and email_verified are defined on the model" do
        let(:mock_user_data) do
          {
            'email' => 'foo@email.com',
            'password' => 'some password',
            'connection' => 'Username-Password-Authentication',
            'email_verified' => true,
            'user_metadata' => { 'foo' => 'bar' }
          }
        end

        before do
          expect(test_model).to receive(:password).and_return('some password')
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
            'user_metadata' => { 'foo' => 'bar' }
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
            'user_metadata' => { 'foo' => 'bar' }
          }
        end
        let(:test_model) { TestModelWithoutEmailVerified.new }

        before do
          expect(test_model).to receive(:password).and_return('some password')
        end

        it "should add the user to auth0 with a default email_verified and update the local user with the auth0 user id" do
          # Do Nothing (test performed by after block)
        end
      end

      after do
        expect(::SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).and_return(mock_auth0_client)
        expect(mock_auth0_client).to receive(:create_user).with('new name', mock_user_data).and_return({ 'user_id' => 'auth0|user_id' })

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
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:create_auth0_client)

        expect(test_model.sync_attr_with_auth0).to eql(true)
      end
    end

    context "when there is no uid on the user" do
      before { expect(test_model).to receive(:uid).and_return(nil) }

      it "returns true" do
        expect(::SyncAttrWithAuth0::Auth0).not_to receive(:create_auth0_client)

        expect(test_model.sync_attr_with_auth0).to eql(true)
      end
    end

    context "when there is a uid on the user" do
      context "when password is not being updated" do
        let(:mock_user_data) do
          {
            'app_metadata' => {
              'name' => 'John Doe',
              'nickname' => 'John Doe',
              'given_name' => 'John',
              'family_name' => 'Doe'
            },
            'user_metadata' => { 'foo' => 'bar' }
          }
        end

        before do
          expect(test_model).to receive(:uid).and_return('the uid')
          expect(test_model).to receive(:auth0_user_metadata).and_return({ 'foo' => 'bar' })
          expect(::SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).and_return(mock_auth0_client)

          expect(test_model).to receive(:name).twice.and_return('John Doe')
          expect(test_model).to receive(:given_name).and_return('John')
          expect(test_model).to receive(:family_name).and_return('Doe')

          expect(test_model).to receive(:password).and_return(nil)
        end

        it "updates the information in auth0 and returns true" do
          expect(mock_auth0_client).to receive(:patch_user).with('the uid', mock_user_data)

          expect(test_model.sync_attr_with_auth0).to eql(true)
        end
      end

      context "when password is being updated" do
        let(:mock_user_data) do
          {
            'app_metadata' => {
              'name' => 'John Doe',
              'nickname' => 'John Doe',
              'given_name' => 'John',
              'family_name' => 'Doe'
            },
            'password' => 'new password',
            'verify_password' => true,
            'user_metadata' => { 'foo' => 'bar' }
          }
        end

        before do
          expect(test_model).to receive(:uid).and_return('the uid')
          expect(test_model).to receive(:auth0_user_metadata).and_return({ 'foo' => 'bar' })
          expect(::SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).and_return(mock_auth0_client)

          expect(test_model).to receive(:name).twice.and_return('John Doe')
          expect(test_model).to receive(:given_name).and_return('John')
          expect(test_model).to receive(:family_name).and_return('Doe')

          expect(test_model).to receive(:password).twice.and_return('new password')
          expect(test_model).to receive(:verify_password).and_return(true)
        end

        it "updates the information in auth0 and returns true" do
          expect(mock_auth0_client).to receive(:patch_user).with('the uid', mock_user_data)

          expect(test_model.sync_attr_with_auth0).to eql(true)
        end
      end
    end

  end


end
