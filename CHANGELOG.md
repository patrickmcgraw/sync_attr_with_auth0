# Changelog

## 0.2.6
* Allow newer Auth0 library and jwt library

## 0.2.5
* No Changes (version bump).

## 0.2.4
* Fixed issue with updating a user where a user on a different strategy than the database connection can't have its name attributes updated.

## 0.2.3
* Updated the user sync to stop storing the user name fields on app_metadata.
* Updated the mock exception throwing to support working with newer versions of the auth0 gem.

## 0.2.2
* Updated the versions of various gem dependencies.
* Updated the user sync to store the user name fields directly on the user. We'll remove them from the app_metadata in a future version.

## 0.2.1
* Replacing calls to UUIDTools::UUID.timestamp_create to be UUIDTools::UUID.random_create instead to resolve an error with GCloud hosting.

## 0.2.0
* No Changes (version bump).

## 0.1.9
* Updated the update_user call to not send the verification email if the email is already verified.

## 0.1.8
* Removed specific version requirement for json gem.
* Loosened the jwt gem version dependency.

## 0.1.7
* Fixing issue with email uniqueness validation finding unrelated email addresses.

## 0.1.6
* Updating SyncAttrWithAuth0::Auth0#find_by_users back to using a lucene email search.

## 0.1.5
* Updating SyncAttrWithAuth0::Auth0#find_by_users to use new v2 users-by-email endpoint instead of a search.

## 0.1.4
* Upgrading the versions of gem dependencies, including jwt.

## 0.1.3
* Renamed SyncAttrWithAuth0::Adapters::ActiveRecord::Sync to be Auth0Sync to prevent collisions.

## 0.1.2
* Updated the user search to support filtering the current user's Auth0 user id from the results.

## 0.1.1
* Updated the create to submit the app_metadata hash.

## 0.1.0
* Updated the configuration so a config block can be used. Any setting on the model will override the config block.
* Changed the default for the Auth0 namespace setting to look at 'AUTH0_NAMESPACE' instead of 'AUTH0_DOMAIN'.
* Changed the attribute settings to use non-abbreviated variable names.
* Updated the usage to include the fields to sync separate from the rest of the config.
* A bunch of refactoring of methods into multiple modules to hopefully improve future maintenance (Configuration, Validation, Sync, etcetera).
* Updated the sync so on create and on update, it determines if the sync to Auth0 should be a create or patch separately (to resolve issues with data inconsistency).
* Updated the Auth0 update to always submit passwords and emails when they are changed, even if they are not fields to sync (that shouldn't be a requirement).

## 0.0.25
* Slackening the rest-client dependency.

## 0.0.24
* Added the ability to sync email changes to Auth0.

## 0.0.23
* Changed the Auth0 user id updates to occur after-commit instead of within the create or update transaction.

## 0.0.22
* If the password is the only change, the gem will still update with Auth0.

## 0.0.21
* Added a check to see if the sync'd attributes have changed to determine if the update callback should run.

## 0.0.20
* Expanded the handler for the situation where the local user record has an invalid Auth0 user id to lookup the user or create it.

## 0.0.19

## 0.0.18
* Added some simple error handling for when the local user has an invalid Auth0 user id.

## 0.0.17
* Added validation for the required environment variables.

## 0.0.16
* Updated the default password to contain a capital letter.

## 0.0.15
* Updated to only submit the password if it's being changed.
* If the password is not stored on the local user record, setting the password attribute will be considered the same as changing the value.

## 0.0.14
* Added the ability to send password changes on-update.

## 0.0.13
* Added auth0 and jwt gems as dependencies.
* Switched to using the auth0 gem to make API calls to Auth0.
* Updated the options for the gem.
* Updated the sync to always push all the data.

## 0.0.12

## 0.0.11

## 0.0.10

## 0.0.9
* Made the attribute options unique to prevent collisions.
* Suppressed the create when the user record already has an Auth0 user id.

## 0.0.8
* Temporarily resolving an issue where the email_verfied attribute does not have a boolean value.

## 0.0.7

## 0.0.6

## 0.0.5
* Updated to handle the password and email_verified missing on the model.

## 0.0.4
* Made the "ok to validate" and "ok to sync" checks assume it's ok if the attributes controlling the decision are missing on the model.

## 0.0.3
* Added additional Auth0 API support for create, updating emails, updating passwords, validating emails, etcetera.

## 0.0.2
* Removed sqlite development dependency.

## 0.0.1
* Initial Release
