require "kemal"
require "kemal-basic-auth"

# Enable HTTP Basic Authentication
# This will protect all routes with username/password authentication.
# Credentials come from the environment so they never live in source;
# startup fails if they are missing instead of falling back to a default.
# Basic auth sends credentials in plain text: serve it over HTTPS only.
basic_auth ENV["BASIC_AUTH_USER"], ENV["BASIC_AUTH_PASSWORD"]

# Define a route for the root path "/"
get "/" do |_|
  # This route will only execute if authentication is successful
  # Otherwise, the browser will show a login prompt
  "This is shown if basic auth successful."
end

# Start the Kemal web server
Kemal.run
