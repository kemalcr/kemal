require "kemal"
require "kemal-basic-auth"

# Enable HTTP Basic Authentication
# This will protect all routes with username/password authentication
# - username: "username"
# - password: "password"
basic_auth "username", "password"

# Define a route for the root path "/"
get "/" do |_|
  # This route will only execute if authentication is successful
  # Otherwise, the browser will show a login prompt
  "This is shown if basic auth successful."
end

# Start the Kemal web server
Kemal.run
