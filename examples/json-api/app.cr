require "kemal"
require "json"

# Set JSON content type for all routes
before_all do |env|
  env.response.content_type = "application/json"
end

# In-memory storage for users
USERS = [] of Hash(String, JSON::Any)

# Returns the id only when it names an existing user. A bare `to_i` would let
# "-1" reach the last user and crash on anything that is not a number.
def user_id(env) : Int32?
  id = env.params.url["id"].to_i?
  id if id && 0 <= id < USERS.size
end

# Parses the body as a JSON object, or returns nil when it is missing,
# malformed, or not an object
def user_body(env) : Hash(String, JSON::Any)?
  body = env.request.body
  JSON.parse(body.gets_to_end).as_h? if body
rescue JSON::ParseException
  nil
end

def bad_body(env) : String
  env.response.status_code = 400
  {error: "Body must be a JSON object"}.to_json
end

# GET - List all users
get "/users" do |_|
  USERS.to_json
end

# GET - Get a specific user by index
get "/users/:id" do |env|
  if id = user_id(env)
    USERS[id].to_json
  else
    env.response.status_code = 404
    {error: "User not found"}.to_json
  end
end

# POST - Create a new user
post "/users" do |env|
  next bad_body(env) unless user = user_body(env)
  USERS << user

  env.response.status_code = 201
  user.to_json
end

# PUT - Update a user
put "/users/:id" do |env|
  # Read the body before looking up the id: reading can yield to another
  # request, and a DELETE in between would shift the indexes
  next bad_body(env) unless updated_user = user_body(env)

  if id = user_id(env)
    USERS[id] = updated_user
    updated_user.to_json
  else
    env.response.status_code = 404
    {error: "User not found"}.to_json
  end
end

# DELETE - Remove a user
delete "/users/:id" do |env|
  if id = user_id(env)
    deleted_user = USERS.delete_at(id)
    deleted_user.to_json
  else
    env.response.status_code = 404
    {error: "User not found"}.to_json
  end
end

# Start the Kemal web server
Kemal.run
