# sync_attr_with_auth0
[![Code Climate](https://codeclimate.com/github/patrickmcgraw/sync_attr_with_auth0/badges/gpa.svg)](https://codeclimate.com/github/patrickmcgraw/sync_attr_with_auth0)  [![Test Coverage](https://codeclimate.com/github/patrickmcgraw/sync_attr_with_auth0/badges/coverage.svg)](https://codeclimate.com/github/patrickmcgraw/sync_attr_with_auth0)

Synchronize attributes on a local ActiveRecord user model with the user metadata store on Auth0.

This gem will validate the email is unique on auth0, create the user on auth0, as well as keep the information you select up-to-date with auth0.

## Important info regarding v0.2.2
We're migrating user name information off of the app_metadata hash, and instead setting them directly on the user (which is what it should have been doing). Make sure anything reading the user name, nickname, given_name, and family_name is no longer reading them from app_metadata.  For backwards compatibility, we're still syncing there with this version, but a future version will have it removed.

## Important info regarding v0.1
There were significant changes to the configuration and usage of the gem as of v0.1.  The readme reflects the current version of that. Please see the changelog for more info about the changes.

## Usage

**sync_attr_with_auth0** fields, options

### Options

**auth0_namespace** (defaults to the value of ENV['AUTH0_NAMESPACE'] )
:   The Auth0 namespace required for API calls.

**auth0_global_client_id** (defaults to the value of ENV['AUTH0_GLOBAL_CLIENT_ID'] )
:   The Auth0 global client id required for API v2 calls.

**auth0_global_client_secret** (defaults to the value of ENV['AUTH0_GLOBAL_CLIENT_SECRET'] )
:   The Auth0 global client secret required for API v2 calls.

**auth0_client_id** (defaults to the value of ENV['AUTH0_CLIENT_ID'] )
:   The Auth0 client id required for API v1 calls.

**auth0_client_secret** (defaults to the value of ENV['AUTH0_CLIENT_SECRET'] )
:   The Auth0 client secret required for API v1 calls.

**auth0_uid_attribute** (default = :auth0_uid)
:   A symbol of the attribute containing the auth0 user id.

**name_attribute** (default = :name)
:   A symbol of the attribute or method containing the auth0 user's full name.

**given_name_attribute** (default = :given_name)
:   A symbol of the attribute containing the auth0 user's first or given name.

**family_name_attribute** (default = :family_name)
:   A symbol of the attribute containing the auth0 user's last or family name.

**email_attribute** (default = :email)
:   A symbol of the attribute containing the email address.

**password_attribute** (default = :password)
:   A symbol of the attribute containing the password.

**email_verified_attribute** (default = :email_verified)
:   A symbol of the attribute containing if the email has been verified.

**verify_password_attribute** (default = :verify_password)
:   A symbol of the attribute containing if the password needs to be verified.

**picture_attribute** (default = :picture)
:   A symbol of the attribute containing the Auth0 picture.

**connection_name** (default = 'Username-Password-Authentication')
:   A string containing the database connection name.

**search_connections** (default = [])
:   A list of connection names to search when finding existing users. If left
    empty all users will be searched.

### Example
``` ruby
class User < ActiveRecord::Base
  sync_attr_with_auth0 :first_name, :last_name, :user_role,
    auth0_uid_attribute: :uid,
    given_name_attribute: :first_name,
    last_name_attribute: :last_name
end
```

The gem utilizes the following callbacks:

**after_validation**
:   The gem verifies the email address is unique in Auth0 if the email address is being changed.  This can be suppressed by setting the attribute "validate_with_auth0" to false on the model.

**after_create**
:   The gem saves the user with the synchronized attributes in Auth0 and updates the local user with the auth0 user id.  This can be suppressed by setting the attribute "sync_with_auth0_on_create" to false on the model.

**after_update**
:   The gem saves the user on Auth0 with the synchronized attributes.  If the email or password are changed, it includes the data necessary to update auth0 (they are otherwise not sent to Auth0).  This can be suppressed by setting the attribute "sync_with_auth0_on_update" to false on the model.

## Configuration Parameters

You can handle a bunch of configuration params through an initializer:

``` ruby
SyncAttrWithAuth0.configure do |config|

  # To set the default Auth0 API settings
  #
  # config.auth0_global_client_id = ENV['AUTH0_GLOBAL_CLIENT_ID']
  # config.auth0_global_client_secret = ENV['AUTH0_GLOBAL_CLIENT_SECRET']
  # config.auth0_client_id = ENV['AUTH0_CLIENT_ID']
  # config.auth0_client_secret = ENV['AUTH0_CLIENT_SECRET']
  # config.auth0_namespace = ENV['AUTH0_NAMESPACE']

  # To set the default connection name for Auth0
  #
  # config.connection_name = 'Username-Password-Authentication'

  # To set the connection to search for existing users
  #
  # config.search_connections = ['Username-Password-Authentication']

  # To set the default attribute names
  #
  # config.auth0_uid_attribute = :auth0_uid
  # config.name_attribute = :name
  # config.given_name_attribute = :given_name
  # config.family_name_attribute = :family_name
  # config.email_attribute = :email
  # config.password_attribute = :password
  # config.email_verified_attribute = :email_verified
  # config.verify_password_attribute = :verify_password
end
```
