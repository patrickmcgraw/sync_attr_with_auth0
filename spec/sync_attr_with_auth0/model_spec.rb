RSpec.describe SyncAttrWithAuth0::Model do

  describe "ActiveRecord::Base" do
    it "responds to ::sync_attr_with_auth0" do
      expect(ActiveRecord::Base.respond_to?(:sync_attr_with_auth0)).to eql(true)
    end
  end

  class TestModel
    include SyncAttrWithAuth0::Model

    class_attribute :_after_save
    self._after_save = []
    def self.after_save(callback)
      self._after_save << callback
    end

    def changes; end;
    def name; end;
    def uid; end;

    sync_attr_with_auth0 :uid, [:name]
  end

  let(:test_model) { TestModel.new }

  it "has #sync_attr_with_auth0 as an after_save callback" do
    expect(TestModel._after_save).to eql([:sync_attr_with_auth0])
  end

  it "responds to #sync_attr_with_auth0" do
    expect(test_model.respond_to?(:sync_attr_with_auth0)).to eql(true)
  end

  describe "#sync_attr_with_auth0" do

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

  end


end
