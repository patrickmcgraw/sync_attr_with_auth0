require 'spec_helper'

RSpec.describe SyncAttrWithAuth0 do
  describe "configuration" do
    subject { SyncAttrWithAuth0 }

    before do
      subject.reset_configuration
    end

    context "when no configuration is set" do
      it "uses a series of default settings" do
        expect(subject.configuration.auth0_uid_attribute).to eq(:auth0_uid)
        expect(subject.configuration.name_attribute).to eq(:name)
        expect(subject.configuration.given_name_attribute).to eq(:given_name)
        expect(subject.configuration.family_name_attribute).to eq(:family_name)
        expect(subject.configuration.email_attribute).to eq(:email)
        expect(subject.configuration.password_attribute).to eq(:password)
        expect(subject.configuration.email_verified_attribute).to eq(:email_verified)
        expect(subject.configuration.verify_password_attribute).to eq(:verify_password)
        expect(subject.configuration.connection_name).to eq('Username-Password-Authentication')
      end
    end

    context "when it is configured by block" do
      before do
        subject.configure do |config|
          config.auth0_uid_attribute = :custom_uid
          config.name_attribute = :custom_name
          config.given_name_attribute = :custom_given_name
          config.family_name_attribute = :custom_family_name
          config.email_attribute = :custom_email
          config.password_attribute = :custom_password
          config.email_verified_attribute = :custom_email_verified
          config.verify_password_attribute = :custom_verify_password
          config.connection_name = 'Custom Connection Name'
        end
      end

      it "updates the defaults" do
        expect(subject.configuration.auth0_uid_attribute).to eq(:custom_uid)
        expect(subject.configuration.name_attribute).to eq(:custom_name)
        expect(subject.configuration.given_name_attribute).to eq(:custom_given_name)
        expect(subject.configuration.family_name_attribute).to eq(:custom_family_name)
        expect(subject.configuration.email_attribute).to eq(:custom_email)
        expect(subject.configuration.password_attribute).to eq(:custom_password)
        expect(subject.configuration.email_verified_attribute).to eq(:custom_email_verified)
        expect(subject.configuration.verify_password_attribute).to eq(:custom_verify_password)
        expect(subject.configuration.connection_name).to eq('Custom Connection Name')
      end
    end

    context "when it is configured by the ActiveRecord class" do
      class DefaultConfigExample
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

        attr_accessor :foo

        sync_attr_with_auth0 :foo
      end

      class CustomConfigExample
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

        attr_accessor :foo

        sync_attr_with_auth0 :foo, {
          auth0_uid_attribute: :custom_uid,
          name_attribute: :custom_name,
          given_name_attribute: :custom_given_name,
          family_name_attribute: :custom_family_name,
          email_attribute: :custom_email,
          password_attribute: :custom_password,
          email_verified_attribute: :custom_email_verified,
          verify_password_attribute: :custom_verify_password,
          connection_name: 'Custom Connection Name'
        }
      end

      it "updates the defaults for that class" do
        expect(DefaultConfigExample.new.auth0_sync_configuration.auth0_uid_attribute).to eq(:auth0_uid)
        expect(DefaultConfigExample.new.auth0_sync_configuration.name_attribute).to eq(:name)
        expect(DefaultConfigExample.new.auth0_sync_configuration.given_name_attribute).to eq(:given_name)
        expect(DefaultConfigExample.new.auth0_sync_configuration.family_name_attribute).to eq(:family_name)
        expect(DefaultConfigExample.new.auth0_sync_configuration.email_attribute).to eq(:email)
        expect(DefaultConfigExample.new.auth0_sync_configuration.password_attribute).to eq(:password)
        expect(DefaultConfigExample.new.auth0_sync_configuration.email_verified_attribute).to eq(:email_verified)
        expect(DefaultConfigExample.new.auth0_sync_configuration.verify_password_attribute).to eq(:verify_password)
        expect(DefaultConfigExample.new.auth0_sync_configuration.connection_name).to eq('Username-Password-Authentication')

        expect(CustomConfigExample.new.auth0_sync_configuration.auth0_uid_attribute).to eq(:custom_uid)
        expect(CustomConfigExample.new.auth0_sync_configuration.name_attribute).to eq(:custom_name)
        expect(CustomConfigExample.new.auth0_sync_configuration.given_name_attribute).to eq(:custom_given_name)
        expect(CustomConfigExample.new.auth0_sync_configuration.family_name_attribute).to eq(:custom_family_name)
        expect(CustomConfigExample.new.auth0_sync_configuration.email_attribute).to eq(:custom_email)
        expect(CustomConfigExample.new.auth0_sync_configuration.password_attribute).to eq(:custom_password)
        expect(CustomConfigExample.new.auth0_sync_configuration.email_verified_attribute).to eq(:custom_email_verified)
        expect(CustomConfigExample.new.auth0_sync_configuration.verify_password_attribute).to eq(:custom_verify_password)
        expect(CustomConfigExample.new.auth0_sync_configuration.connection_name).to eq('Custom Connection Name')
      end
    end
  end # configuration
end
