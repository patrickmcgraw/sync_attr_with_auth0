require 'spec_helper'

module SyncAttrWithAuth0
  module Adapters

    RSpec.describe ActiveRecord do

      class ActiveRecordExample
        extend ActiveModel::Naming
        extend ActiveModel::Callbacks
        define_model_callbacks :commit, :only => :after
        define_model_callbacks :create, :only => :after
        define_model_callbacks :update, :only => :after

        include ActiveModel::Validations
        include ActiveModel::Validations::Callbacks
        include ActiveModel::Conversion

        include ActiveModel::Dirty
        include ::SyncAttrWithAuth0::Adapters::ActiveRecord

        attributes_array = [:email, :password, :given_name, :family_name,
                            :name, :uid, :foo, :bar]

        attr_accessor(*attributes_array)
        define_attribute_methods(*attributes_array)

        sync_attr_with_auth0 :name, :email, :password, :foo, :undefined_attribute,
          auth0_uid_attribute: :uid
      end # active record example

      subject { ActiveRecordExample.new }


      describe "#auth0_attributes_to_sync" do
        it "returns a collection of attributes to sync" do
          expect(subject.auth0_attributes_to_sync).to eq([:name, :email, :password, :foo, :undefined_attribute])
        end
      end # auth0_attributes_to_sync


      describe "#setup_auth0_sync_configuration" do
        it "creates a copy of the configuration object with the model-specific changes" do
          expect(subject.setup_auth0_sync_configuration.auth0_uid_attribute).to eq(:uid)
        end
      end # setup_auth0_sync_configuration


      describe "#auth0_sync_configuration" do
        before { allow(subject).to receive(:setup_auth0_sync_configuration).and_return('setup config') }

        context "when the instance config is not set" do
          before { subject.instance_variable_set(:@auth0_sync_configuration, nil) }

          it "should setup the config" do
            expect(subject.auth0_sync_configuration).to eq('setup config')
          end
        end

        context "when the instance config is set" do
          before { subject.instance_variable_set(:@auth0_sync_configuration, 'instance config') }

          it "should reference the instance config" do
            expect(subject.auth0_sync_configuration).to eq('instance config')
          end
        end
      end # auth0_sync_configuration

    end # describe ActiveRecord

  end
end
