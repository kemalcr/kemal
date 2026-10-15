require "kemal"
require "kemal-basic-auth"

# Enable HTTP Basic Authentication for all routes
# Credentials come from ENV, never source; refuse to start if unset or empty.
# Basic auth sends them in plain text: serve it over HTTPS only.
username = ENV["BASIC_AUTH_USER"]?.presence
password = ENV["BASIC_AUTH_PASSWORD"]?.presence
abort "Set BASIC_AUTH_USER and BASIC_AUTH_PASSWORD" unless username && password
basic_auth username, password

# Define a route for the root path "/"
get "/" do |_|
  # This route will only execute if authentication is successful
  # Otherwise, the browser will show a login prompt
  "This is shown if basic auth successful."
end

# Start the Kemal web server
Kemal.run
