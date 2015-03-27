# sync_attr_with_auth0
Synchronize attributes on a local ActiveRecord user model with the user metadata store on Auth0.

This gem will validate the email is unique on auth0, create the user on auth0, as well as keep the information you select up-to-date with auth0.

## Usage

**sync_attr_with_auth0** options

### Options

**uid_att** (default = :uid)
:   A symbol of the attribute containing the auth0 user id.

**email_att** (default = :email)
:   A symbol of the attribute containing the email address.

**password_att** (default = :password)
:   A symbol of the attribute containing the password.

**email_verified_att** (default = :email_verified)
:   A symbol of the attribute containing if the email has been verified.

**connection_name** (default = 'Username-Password-Authentication')
:   A string containing the database connection name.

**sync_atts** (default = [])
:   An array of symbols of the attributes to sync with auth0.

### Example
``` ruby
class User < ActiveRecord::Base
  sync_attr_with_auth0 uid_att: :auth0_uid, sync_atts: [:first_name, :last_name, :email]
end
```

The gem utilizes the following callbacks:

**after_validation**
:   verifies the email address is unique in auth0 if the email address is being changed.  This can be suppressed by setting the attribute "validate_with_auth0" to false on the model.

**after_create**
:   creates the user with the synchronized attributes in auth0 and updates the local user with the auth0 user id.  This can be suppressed by setting the attribute "sync_with_auth0_on_create" to false on the model.

**after_update**
:   updates the user on auth0 with the synchronized attributes.  If the email or password is being synchronized, it makes the separate API calls necessary to update auth0.  This can be suppressed by setting the attribute "sync_with_auth0_on_update" to false on the model.
