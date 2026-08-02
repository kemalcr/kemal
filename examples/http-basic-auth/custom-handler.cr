require "kemal-basic-auth"

# Create a custom authentication handler by inheriting from Kemal::BasicAuth::Handler
class CustomAuthHandler < Kemal::BasicAuth::Handler
  # Protect /dashboard and /admin (and their subpaths) for every HTTP method.
  # `only` defaults to GET + exact path — insufficient for auth. Use "/*" for
  # prefix matching and "*" for all methods. For subtree middleware without
  # method filtering, prefer: use "/admin", AuthHandler.new
  only ["/dashboard/*", "/admin/*"], "*"

  # Override the call method to implement custom authentication logic
  def call(context)
    # Skip authentication if the current route is not in the protected routes list
    # This allows other routes to be accessed without authentication
    return call_next(context) unless only_match?(context)

    # Call the parent class's authentication logic for protected routes
    # This will prompt for username/password and validate credentials
    super
  end
end

# Register our custom authentication handler with Kemal
# This enables basic auth for the specified routes
Kemal.config.auth_handler = CustomAuthHandler
