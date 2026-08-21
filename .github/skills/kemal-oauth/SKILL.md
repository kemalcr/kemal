---
name: kemal-oauth
description: Implementing OAuth2 authentication in Kemal, following established project patterns.
license: MIT
---

# Kemal OAuth2 Integration

This skill provides expert guidance on integrating OAuth2 authentication (e.g., GitHub, Google) into Kemal applications, strictly following patterns from [`kemal-by-example/oauth-login`](https://github.com/sdogruyol/kemal-by-example/tree/master/oauth-login).

## Core Mandates

- **Dependencies:** The route examples below use `env.session` and `env.flash`, both provided by [`kemal-session`](https://github.com/kemalcr/kemal-session) (`env.flash` since kemal-session 1.4.0). Add it to `shard.yml` and `require "kemal-session"`.
- **Configuration:** Use environment variables for client IDs and secrets:

  ```crystal
  def client_id : String
    ENV["GITHUB_CLIENT_ID"]? || ""
  end

  def client_secret : String
    ENV["GITHUB_CLIENT_SECRET"]? || ""
  end

  def redirect_uri : String
    ENV["OAUTH_REDIRECT_URI"]? || "http://127.0.0.1:3000/auth/github/callback"
  end
  ```

- **Authorization URL:** Use `URI::Params` to construct the authorization URL with required scopes and a state parameter:

  ```crystal
  def authorize_url(state : String) : String
    params = URI::Params.build do |form|
      form.add "client_id", client_id
      form.add "redirect_uri", redirect_uri
      form.add "scope", "read:user user:email"
      form.add "state", state
    end
    "https://github.com/login/oauth/authorize?#{params}"
  end
  ```

- **State Parameter:** Generate state with `Random::Secure.random_bytes(16).hexstring`, store in `env.session`, verify in callback, then delete:

  ```crystal
  # In authorization route:
  state = Random::Secure.random_bytes(16).hexstring
  env.session.string("oauth_state", state)

  # In callback:
  stored = env.session.string?("oauth_state")
  env.session.delete_string("oauth_state")
  halt env.status(:forbidden) unless state == stored
  ```

- **Exchanging Code:** Use `HTTP::Client` to exchange the authorization code for an access token. Always set `Accept`, `Content-Type`, and `User-Agent` headers:

  ```crystal
  response = HTTP::Client.post(
    "https://github.com/login/oauth/access_token",
    headers: HTTP::Headers{
      "Accept"       => "application/json",
      "Content-Type" => "application/x-www-form-urlencoded",
      "User-Agent"   => "my-app",
    },
    body: URI::Params.encode({
      "client_id"     => client_id,
      "client_secret" => client_secret,
      "code"          => code,
      "redirect_uri"  => redirect_uri,
    })
  )
  return nil unless response.success?
  json = JSON.parse(response.body)
  json["access_token"]?.try(&.as_s?)
  rescue JSON::ParseException
    nil
  ```

## Patterns from Source Code

### OAuth Service Module (oauth-login/src/services/github_oauth.cr)

```crystal
require "http/client"
require "json"
require "uri"

module OauthLogin
  module GithubOauth
    extend self

    USER_AGENT = "kemal-oauth-login"

    def client_id : String
      ENV["GITHUB_CLIENT_ID"]? || ""
    end

    def client_secret : String
      ENV["GITHUB_CLIENT_SECRET"]? || ""
    end

    def redirect_uri : String
      ENV["OAUTH_REDIRECT_URI"]? || "http://127.0.0.1:3000/auth/github/callback"
    end

    def configured? : Bool
      !client_id.empty? && !client_secret.empty?
    end

    def authorize_url(state : String) : String
      params = URI::Params.build do |form|
        form.add "client_id", client_id
        form.add "redirect_uri", redirect_uri
        form.add "scope", "read:user user:email"
        form.add "state", state
      end
      "https://github.com/login/oauth/authorize?#{params}"
    end

    def exchange_code(code : String) : String?
      body = URI::Params.encode({
        "client_id"     => client_id,
        "client_secret" => client_secret,
        "code"          => code,
        "redirect_uri"  => redirect_uri,
      })
      response = HTTP::Client.post(
        "https://github.com/login/oauth/access_token",
        headers: HTTP::Headers{
          "Accept"       => "application/json",
          "Content-Type" => "application/x-www-form-urlencoded",
          "User-Agent"   => USER_AGENT,
        },
        body: body
      )
      return nil unless response.success?

      json = JSON.parse(response.body)
      json["access_token"]?.try(&.as_s?)
    rescue JSON::ParseException
      nil
    end

    def fetch_github_user(access_token : String) : Hash(String, JSON::Any)?
      response = HTTP::Client.get(
        "https://api.github.com/user",
        headers: HTTP::Headers{
          "Authorization" => "Bearer #{access_token}",
          "Accept"        => "application/vnd.github+json",
          "User-Agent"    => USER_AGENT,
        }
      )
      return nil unless response.success?

      JSON.parse(response.body).as_h?
    rescue JSON::ParseException
      nil
    end
  end
end
```

### OAuth Routes (oauth-login/src/routes/oauth.cr)

`env.flash` below is kemal-session's one-time flash message helper (see Dependencies above).

```crystal
require "random"

get "/auth/github" do |env|
  unless OauthLogin::GithubOauth.configured?
    env.flash["error"] = "Set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET. See README."
    env.redirect "/"
    next
  end

  state = Random::Secure.random_bytes(16).hexstring
  env.session.string("oauth_state", state)
  env.redirect OauthLogin::GithubOauth.authorize_url(state)
end

get "/auth/github/callback" do |env|
  code = env.params.query["code"]?
  state = env.params.query["state"]?
  stored = env.session.string?("oauth_state")
  env.session.delete_string("oauth_state")

  unless code && state && stored && state == stored
    env.flash["error"] = "OAuth state mismatch or missing code."
    env.redirect "/"
    next
  end

  token = OauthLogin::GithubOauth.exchange_code(code)
  unless token
    env.flash["error"] = "Could not exchange code for token."
    env.redirect "/"
    next
  end

  # ... fetch user, sign in, redirect
end
```

## Best Practices

- **Service Isolation:** Encapsulate OAuth logic within dedicated service modules (e.g., `GithubOauth`).
- **Error Handling:** Gracefully handle API errors and JSON parsing failures during the OAuth flow using specific exception types.
- **Session Security:** Use `env.session` for state management throughout the OAuth lifecycle. Always clean up state after verification.
- **Profile Fetching:** Use the access token to fetch user profile information using `HTTP::Client` with appropriate `Authorization: Bearer` headers.
- **Configured Check:** Check if OAuth is configured before redirecting to avoid errors.

## When to Use

- When implementing "Login with GitHub/Google" features.
- When interacting with external APIs that require OAuth2 authentication.
- When managing OAuth flows and callbacks in a Kemal application.
