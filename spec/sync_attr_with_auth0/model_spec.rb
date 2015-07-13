RSpec.describe SyncAttrWithAuth0::Model do

  describe "ActiveRecord::Base" do
    it "responds to ::sync_attr_with_auth0" do
      expect(ActiveRecord::Base.respond_to?(:sync_attr_with_auth0)).to eql(true)
    end
  end

  class TestModel
    extend ActiveModel::Naming
    extend ActiveModel::Callbacks
    define_model_callbacks :commit, :only => :after
    define_model_callbacks :create, :only => :after
    define_model_callbacks :update, :only => :after

    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    include ActiveModel::Conversion

    # include ActiveRecord::Callbacks
    include ActiveModel::Dirty
    include SyncAttrWithAuth0::Model

    attributes_array = [:email, :password, :given_name, :family_name,
                        :name, :uid, :foo, :bar]

    attr_accessor(*attributes_array)
    define_attribute_methods(*attributes_array)

    def save; end;

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
    expect(FullTestModel._validation_callbacks.collect(&:filter)).to eql([:validate_email_with_auth0])
  end

  it "has #sync_attr_with_auth0 as an after_create callback" do
    expect(FullTestModel._create_callbacks.collect(&:filter)).to eql([:auth0_create])
  end

  it "has #sync_attr_with_auth0 as an after_update callback" do
    expect(FullTestModel._update_callbacks.collect(&:filter)).to eql([:auth0_update])
    expect(FullTestModel._update_callbacks.first.instance_variable_get(:"@if").first).to eql(:auth0_dirty?)
  end

  it "has #auth0_set_uid as an after_commit callback" do
    expect(FullTestModel._commit_callbacks.collect(&:filter)).to eql([:auth0_set_uid])
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

  describe "#auth0_create" do
    context "when suppressing sync on create" do
      before { expect(test_model).to receive(:sync_with_auth0_on_create).at_least(1).and_return(false) }

      it "returns true" do
        expect(test_model).not_to receive(:create_user_in_auth0)

        expect(test_model.auth0_create).to eql(true)
      end
    end

    context "when the user already has a uid" do
      before { expect(test_model).to receive(:uid).at_least(1).and_return('Some User ID') }

      it "returns true" do
        expect(test_model).not_to receive(:create_user_in_auth0)

        expect(test_model.auth0_create).to eql(true)
      end
    end

    context "when not suppressing sync on create" do
      before { expect(test_model).to receive(:uid).at_least(1).and_return(nil) }

      it "returns true" do
        expect(test_model).to receive(:create_user_in_auth0)

        expect(test_model.auth0_create).to eql(true)
      end
    end
  end

  describe "#auth0_update" do

    context "when suppressing sync on update" do
      before { expect(test_model).to receive(:sync_with_auth0_on_update).at_least(1).and_return(false) }

      it "returns true" do
        expect(test_model).not_to receive(:update_user_in_auth0)

        expect(test_model.auth0_update).to eql(true)
      end
    end

    context "when there is no uid on the user" do
      before { expect(test_model).to receive(:uid).and_return(nil) }

      it "returns true" do
        expect(test_model).to_not receive(:update_user_in_auth0)

        expect(test_model.auth0_update).to eql(true)
      end
    end

    context "when there is a uid on the user" do
      before { expect(test_model).to receive(:uid).and_return('some uid') }

      it "returns true" do
        expect(test_model).to receive(:update_user_in_auth0).with('some uid')

        expect(test_model.auth0_update).to eql(true)
      end
    end

  end


  describe "#auth0_set_uid" do
    context "when the instance variable is set" do
      before { test_model.instance_variable_set(:@auth0_uid, 'auth0|user_id') }

      it "should update the user with the auth0 user id and return true" do
        expect(test_model).to receive(:uid=).with('auth0|user_id')
        expect(test_model).to receive(:save).and_return(true)

        expect(test_model.auth0_set_uid).to eql(true)
        expect(test_model.instance_variable_get(:@auth0_uid)).to eq(nil)
      end
    end

    context "when the instance variable is not set" do
      it "should do nothing and return true" do
        expect(test_model.auth0_set_uid).to eql(true)
      end
    end
  end


  describe "#create_user_in_auth0" do
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

    context "when the password is defined on the model, but is nil" do
      let(:mock_user_data) do
        {
          'email' => 'foo@email.com',
          'password' => 'default-password',
          'connection' => 'Username-Password-Authentication',
          'email_verified' => true,
          'user_metadata' => { 'foo' => 'bar' }
        }
      end

      before do
        expect(test_model).to receive(:password).and_return(nil)
        expect(test_model).to receive(:auth0_default_password).and_return('default-password')
        expect(test_model).to receive(:email_verified).and_return(true)
      end

      it "should add the user to auth0 with a default password and update the local user with the auth0 user id" do
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

      test_model.create_user_in_auth0

      expect(test_model.instance_variable_get(:@auth0_uid)).to eq('auth0|user_id')
    end
  end # create_user_in_auth0

  describe "#update_user_in_auth0" do
    let (:mock_response) { double(Object) }

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
        # expect(test_model).to receive(:uid).and_return('the uid')
        expect(test_model).to receive(:auth0_user_metadata).and_return({ 'foo' => 'bar' })
        expect(::SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).and_return(mock_auth0_client)

        expect(test_model).to receive(:name).twice.and_return('John Doe')
        expect(test_model).to receive(:given_name).and_return('John')
        expect(test_model).to receive(:family_name).and_return('Doe')

        expect(test_model).to receive(:auth0_user_password_changed?).and_return(false)
      end

      it "updates the information in auth0 and returns true" do
        expect(mock_auth0_client).to receive(:patch_user).with('the uid', mock_user_data).and_return(mock_response)
        # expect(mock_response).to receive(:code).and_return(200)

        test_model.update_user_in_auth0('the uid')
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
        # expect(test_model).to receive(:uid).and_return('the uid')
        expect(test_model).to receive(:auth0_user_metadata).and_return({ 'foo' => 'bar' })
        expect(::SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).and_return(mock_auth0_client)

        expect(test_model).to receive(:name).twice.and_return('John Doe')
        expect(test_model).to receive(:given_name).and_return('John')
        expect(test_model).to receive(:family_name).and_return('Doe')

        expect(test_model).to receive(:auth0_user_password_changed?).and_return(true)
        expect(test_model).to receive(:password).and_return('new password')
        expect(test_model).to receive(:verify_password).and_return(true)
      end

      it "updates the information in auth0 and returns true" do
        expect(mock_auth0_client).to receive(:patch_user).with('the uid', mock_user_data).and_return(mock_response)
        # expect(mock_response).to receive(:code).and_return(200)

        test_model.update_user_in_auth0('the uid')
      end
    end

    context "when the user is not found in auth0" do
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
        # expect(test_model).to receive(:uid).and_return('the uid')
        expect(test_model).to receive(:auth0_user_metadata).and_return({ 'foo' => 'bar' })
        expect(::SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).and_return(mock_auth0_client)

        expect(test_model).to receive(:name).twice.and_return('John Doe')
        expect(test_model).to receive(:given_name).and_return('John')
        expect(test_model).to receive(:family_name).and_return('Doe')

        expect(test_model).to receive(:auth0_user_password_changed?).and_return(true)
        expect(test_model).to receive(:password).and_return('new password')
        expect(test_model).to receive(:verify_password).and_return(true)

        expect(mock_auth0_client).to receive(:patch_user).with('the uid', mock_user_data).and_raise(::Auth0::NotFound)
      end

      context "when a user with a matching email address can be found" do
        let(:mock_search_result) { double(Object) }
        let(:mock_search_results) { [mock_search_result] }

        before do
          expect(test_model).to receive(:find_user_in_auth0).and_return(mock_search_results)
          expect(mock_search_result).to receive(:[]).with('user_id').at_least(1).and_return('new uid')
          expect(::SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).and_return(mock_auth0_client)
          expect(mock_auth0_client).to receive(:patch_user).with('new uid', mock_user_data).and_return(mock_response)
        end

        it "uses the found uid to update the information in auth0 and updates the uid on the user" do
          test_model.update_user_in_auth0('the uid')

          expect(test_model.instance_variable_get(:@auth0_uid)).to eq('new uid')
        end
      end

      context "when a user with a matching email address can NOT be found" do
        before do
          expect(test_model).to receive(:find_user_in_auth0).and_return([])
          expect(test_model).to receive(:create_user_in_auth0)
        end

        it "creates the user in auth0, forcing a default password if one is not provided" do
          test_model.update_user_in_auth0('the uid')
        end
      end
    end
  end # update_user_in_auth0


  describe "#find_user_in_auth0" do
    before do
      expect(::SyncAttrWithAuth0::Auth0).to receive(:create_auth0_client).and_return(mock_auth0_client)
      expect(test_model).to receive(:email).and_return('bar@email.com')
    end

    context "when the new email does not exist in auth0" do
      it "should return true" do
        expect(mock_auth0_client).to receive(:users).with('email:bar@email.com').and_return([])

        expect(test_model.find_user_in_auth0).to eql([])
      end
    end

    context "when the new email does exist in auth0" do
      it "should return false" do
        expect(mock_auth0_client).to receive(:users).with('email:bar@email.com').and_return(['a result!'])

        expect(test_model.find_user_in_auth0).to eql(['a result!'])
      end
    end
  end # find_user_in_auth0

  describe "#auth0_dirty?" do
    context "when no auth0 attributes are changed" do
      it "returns false" do
        test_model.bar_will_change!
        expect(test_model.changed?).to eql(true)
        expect(test_model.auth0_dirty?).to eql(false)
      end
    end

    context "when some auth0 attributes are changed" do
      it "returns true" do
        test_model.email_will_change!
        expect(test_model.changed?).to eql(true)
        expect(test_model.auth0_dirty?).to eql(true)
      end
    end

    context "when only the password is changed" do
      before { expect(test_model).to receive(:auth0_user_password_changed?).and_return(true) }

      it "returns true" do
        test_model.bar_will_change!
        expect(test_model.changed?).to eql(true)
        expect(test_model.auth0_dirty?).to eql(true)
      end
    end
  end

end
