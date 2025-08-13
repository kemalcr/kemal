require "kemal"
require "json"

# Set JSON content type for all routes
before_all do |env|
  env.response.content_type = "application/json"
end

# In-memory storage for users
USERS = [] of Hash(String, JSON::Any)

# GET - List all users
get "/users" do |_|
  USERS.to_json
end

# GET - Get a specific user by index
get "/users/:id" do |env|
  id = env.params.url["id"].to_i

  if id < USERS.size
    USERS[id].to_json
  else
    env.response.status_code = 404
    {error: "User not found"}.to_json
  end
end

# POST - Create a new user
post "/users" do |env|
  # Parse request body as JSON
  # ameba:disable Lint/NotNil
  user = JSON.parse(env.request.body.not_nil!.gets_to_end)
  # ameba:enable Lint/NotNil
  USERS << user.as_h

  env.response.status_code = 201
  user.to_json
end

# PUT - Update a user
put "/users/:id" do |env|
  id = env.params.url["id"].to_i

  if id < USERS.size
    # Parse request body as JSON
    # ameba:disable Lint/NotNil
    updated_user = JSON.parse(env.request.body.not_nil!.gets_to_end)
    # ameba:enable Lint/NotNil
    USERS[id] = updated_user.as_h
    updated_user.to_json
  else
    env.response.status_code = 404
    {error: "User not found"}.to_json
  end
end

# DELETE - Remove a user
delete "/users/:id" do |env|
  id = env.params.url["id"].to_i

  if id < USERS.size
    deleted_user = USERS.delete_at(id)
    deleted_user.to_json
  else
    env.response.status_code = 404
    {error: "User not found"}.to_json
  end
end

# Start the Kemal web server
Kemal.run
