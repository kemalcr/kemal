---
name: kemal-auth
description: User authentication and session management in Kemal, following established project patterns.
---

# Kemal Authentication & Sessions

This skill provides expert guidance on implementing user authentication and session management in Kemal, strictly following patterns from `src/kemal-by-example/ecommerce/` and `src/kemal-by-example/oauth-login/`.

## Compatibility Matrix

| Feature | Kemal 1.12.0 (Release) | Kemal Master (Unreleased / Next) |
| :--- | :--- | :--- |
| `kemal-session` Integration | Supported | Supported |
| Password Hashing (`Crypto::Bcrypt::Password`) | Supported | Supported |
| Session-backed Auth Middleware & Helpers | Supported | Supported |
| CSRF Protection via POST Actions | Supported | Supported |

## Core Mandates

- **Dependencies:** Always `require "kemal-session"`.
- **Session Configuration:** Use `Kemal::Session.config` to set `secret`, `cookie_name`, and `gc_interval`:

  ```crystal
  Kemal::Session.config do |config|
    config.secret = ENV["KEMAL_SESSION_SECRET"]? || raise "KEMAL_SESSION_SECRET not set"
    config.cookie_name = "your_app_session"
    config.gc_interval = 2.minutes
  end
  ```

- **Auth Helpers:** Implement auth logic in a module (e.g., `Ecommerce::Auth`):
  - `current_user(env)`: Use `env.session.bigint?("user_id")` to retrieve the ID and find the user
  - `require_user(env)`: Call `current_user(env)` and redirect to `/login` if `nil`
  - `sign_in(env, user)`: Set `env.session.bigint("user_id", user.id || raise "User ID required")`
  - `sign_out(env)`: Call `env.session.destroy`

- **Password Hashing:** Use `Crypto::Bcrypt::Password` for securely storing and authenticating passwords.
- **Error Handling:** Use specific exception types (like `DB::Error`) in auth helpers.

  ```crystal
  def current_user(env) : User?
    user_id = env.session.bigint?("user_id")
    return unless user_id
    User.find(user_id)
  rescue DB::Error
    nil
  end
  ```

## Patterns from Source Code

### Auth Helper Module (ecommerce/src/helpers/auth.cr)

```crystal
module Ecommerce
  module Auth
    extend self

    def current_user(env) : User?
      user_id = env.session.bigint?("user_id")
      return unless user_id
      User.find(user_id)
    rescue DB::Error
      nil
    end

    def require_user(env) : User?
      user = current_user(env)
      return user if user
      env.redirect "/login"
      nil
    end

    def sign_in(env, user : User)
      user_id = user.id || raise ArgumentError.new("Cannot sign in user without ID")
      env.session.bigint("user_id", user_id)
    end

    def sign_out(env)
      env.session.destroy
    end
  end
end
```

### Session Secret (Explicit Configuration)

From ecommerce and oauth-login:

```crystal
Kemal::Session.config do |config|
  config.secret = ENV["KEMAL_SESSION_SECRET"]? || raise "KEMAL_SESSION_SECRET not set"
  config.cookie_name = "ecommerce_session_id"
  config.gc_interval = 2.minutes
end
```

### User Model with Bcrypt

From ecommerce/src/models/user.cr:

```crystal
require "crypto/bcrypt"

class User
  include DB::Serializable

  getter id : Int64?
  getter name : String
  getter email : String
  getter password_hash : String
  getter created_at : String
  getter updated_at : String

  def self.create(name : String, email : String, password : String) : User
    now = Time.utc.to_s
    normalized_email = normalize_email(email)
    password_hash = Crypto::Bcrypt::Password.create(password, cost: 12).to_s
    # ... insert and return user
  end

  def self.authenticate(email : String, password : String) : User?
    user = find_by_email(normalize_email(email))
    return unless user
    return user if Crypto::Bcrypt::Password.new(user.password_hash).verify(password)
    nil
  end

  def self.normalize_email(value : String) : String
    value.strip.downcase
  end
end
```

### Login Route Pattern

```crystal
post "/login" do |env|
  email = env.params.body["email"]?.try(&.strip) || ""
  password = env.params.body["password"]?.try(&.strip) || ""
  user = User.authenticate(email, password)

  if user
    Ecommerce::Auth.sign_in(env, user)
    env.redirect "/products"
  else
    current_user = nil
    cart_count = 0_i64
    error_message = "Invalid email or password."
    env.response.status = :unprocessable_entity
    render "src/views/auth/login.ecr", "src/views/layouts/application.ecr"
  end
end

post "/logout" do |env|
  Ecommerce::Auth.sign_out(env)
  env.redirect "/products"
end
```

## Best Practices

- **Local Variables for Errors:** Pass error messages as local variables directly to the `render` macro (e.g., `error_message = "Invalid email or password."`).
- **Security:** Use `POST` for login and logout routes to prevent CSRF.
- **Session Safe Access:** Use `env.session.bigint?("user_id")` or similar to safely retrieve session data.
- **Model Methods:** Implement `User.authenticate(email, password)` and `User.find_by_email(email)` in the model.

## When to Use

- When implementing signup, login, or logout features.
- When protecting specific routes from unauthorized access.
- When managing user-specific state across requests.
