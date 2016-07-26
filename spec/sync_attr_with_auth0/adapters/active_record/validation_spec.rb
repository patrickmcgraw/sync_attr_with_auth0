require 'spec_helper'

module SyncAttrWithAuth0
  module Adapters
    module ActiveRecord

      RSpec.describe Validation do

        class ValidationExample
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
                              :name, :uid, :foo, :bar, :validate_with_auth0]

          attr_accessor(*attributes_array)
          define_attribute_methods(*attributes_array)

          sync_attr_with_auth0 :name, :email, :password, :foo, :undefined_attribute,
            auth0_uid_attribute: :uid
        end # active record example

        subject { ValidationExample.new }


        describe "#validate_with_auth0?" do
          context "when the model doesn't respond to :validate_with_auth0" do
            before { allow(subject).to receive(:respond_to?).with(:validate_with_auth0).and_return(false) }

            it "defaults to true" do
              expect(subject.validate_with_auth0?).to eq(true)
            end
          end

          context "when :validate_with_auth0 is false" do
            before { subject.validate_with_auth0 = false }

            it "should return false" do
              expect(subject.validate_with_auth0?).to eq(false)
            end
          end

          context "when :validate_with_auth0 is true" do
            before { subject.validate_with_auth0 = true }

            it "should return true" do
              expect(subject.validate_with_auth0?).to eq(true)
            end
          end
        end # validate_with_auth0?


        describe "#validate_email_with_auth0?" do
          context "when the model is not validating with auth0" do
            before { allow(subject).to receive(:validate_with_auth0?).and_return(false) }

            it "should return false" do
              expect(subject.validate_email_with_auth0?).to eq(false)
            end
          end

          context "when the model is validating with auth0" do
            before { allow(subject).to receive(:validate_with_auth0?).and_return(true) }

            context "when the email has not changed" do
              before { allow(subject).to receive(:email_changed?).and_return(false) }

              it "should return false" do
                expect(subject.validate_email_with_auth0?).to eq(false)
              end
            end

            context "when the email has changed" do
              before { allow(subject).to receive(:email_changed?).and_return(true) }

              it "should return true" do
                expect(subject.validate_email_with_auth0?).to eq(true)
              end
            end
          end
        end # validate_email_with_auth0?


        describe "#validate_email_with_auth0" do
          context "when not validating the email with auth0" do
            before { allow(subject).to receive(:validate_email_with_auth0?).and_return(false) }

            it "should return true" do
              expect(subject.validate_email_with_auth0).to eq(true)
            end
          end

          context "when validating the email with auth0" do
            before { allow(subject).to receive(:validate_email_with_auth0?).and_return(true) }

            context "when no users are found with a matching email" do
              before { allow(subject).to receive(:users_in_auth0_with_matching_email).and_return([]) }

              it "should return true" do
                expect(subject.validate_email_with_auth0).to eq(true)
              end
            end

            context "when users are found with a matching email" do
              before { allow(subject).to receive(:users_in_auth0_with_matching_email).and_return(['a user']) }

              it "should return false" do
                expect(subject.validate_email_with_auth0).to eq(false)
              end
            end
          end
        end # validate_email_with_auth0


        describe "#users_in_auth0_with_matching_email" do
          let(:mock_client) { double(Object) }
          let(:mock_config) { double(Object, email_attribute: :email) }

          before do
            allow(subject).to receive(:email).and_return('bar@email.com')
            allow(subject).to receive(:auth0_sync_configuration).and_return(mock_config)

            expect(SyncAttrWithAuth0::Auth0).to receive(:find_users_by_email).with('bar@email.com', mock_config).and_return(['a user'])
          end

          it "returns the result of a search in auth0 for users with a matching email" do
            expect(subject.users_in_auth0_with_matching_email).to eq(['a user'])
          end
        end # users_in_auth0_with_matching_email

      end # describe Validation

    end
  end
end
