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
  # Read from JSON but never written back, so no `to_json` can leak it
  @[JSON::Field(ignore_serialize: true)]
  property password : String
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

  # Convert the user object back to JSON; the password is left out
  user.to_json
end

# Start the Kemal web server
Kemal.run
