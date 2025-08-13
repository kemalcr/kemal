require "kemal"
require "db"
require "mysql"

# Initialize a single DB connection
DB_URL = "mysql://root:password@localhost:3306/mydb"
DBC    = DB.open(DB_URL)

# Example User model
class User
  include JSON::Serializable # To render json in HTTP::Response
  include DB::Serializable   # To serialize from DB::ResultSet

  property id : Int32
  property name : String
  property email : String

  def initialize(@id, @name, @email)
  end
end

# List all users
get "/users" do |_|
  # Serialize ResultSet
  users = User.from_rs(DBC.query("SELECT * FROM users"))

  # Return users array as JSON response
  users.to_json
end

# Create a new user
post "/users" do |env|
  name = env.params.json["name"].as(String)
  email = env.params.json["email"].as(String)

  user = User.from_rs(DBC.query("INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email", name, email)).first

  {message: "User created with id: #{user.id}"}.to_json
end

# Delete a user
delete "/users/:id" do |env|
  id = env.params.url["id"].to_i

  # Delete user and check if any rows were affected
  result = DB.exec "DELETE FROM users WHERE id = ?", id

  if result.rows_affected > 0
    {message: "User deleted successfully"}.to_json
  else
    env.response.status_code = 404
    {message: "User not found"}.to_json
  end
end

Kemal.run
