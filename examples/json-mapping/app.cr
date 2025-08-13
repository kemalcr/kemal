require "kemal"
require "json"

# Define a User class that can be created from JSON data
class User
  # Include JSON::Serializable to add JSON parsing capabilities
  # This allows converting JSON strings to User objects and vice versa
  include JSON::Serializable

  # Define properties that will be mapped from JSON
  # These properties must match the keys in the incoming JSON
  property username : String # User's username as a string
  property password : String # User's password as a string
end

# Handle POST requests to the root path "/"
post "/" do |env|
  # Parse the request body as JSON and create a User object
  # env.request.body contains the raw JSON data
  # not_nil! ensures the body exists
  # User.from_json converts the JSON string to a User object
  # ameba:disable Lint/NotNil
  user = User.from_json env.request.body.not_nil!
  # ameba:enable Lint/NotNil

  # Convert the user object back to JSON and return it
  # This creates a JSON object with username and password fields
  {username: user.username, password: user.password}.to_json
end

# Start the Kemal web server
Kemal.run
