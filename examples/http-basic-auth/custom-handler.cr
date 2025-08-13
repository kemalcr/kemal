require "kemal-basic-auth"

# Create a custom authentication handler by inheriting from Kemal::BasicAuth::Handler
class CustomAuthHandler < Kemal::BasicAuth::Handler
  # Specify which routes should be protected by basic auth
  # In this case, only /dashboard and /admin routes will require authentication
  only ["/dashboard", "/admin"]

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
