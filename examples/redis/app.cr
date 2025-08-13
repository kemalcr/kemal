require "kemal"
require "redis"

# Initialize Redis client
REDIS = Redis.new(host: "localhost", port: 6379)

# Store a value
post "/store/:key" do |env|
  key = env.params.url["key"]
  value = env.params.json["value"].as(String)

  REDIS.set(key, value)
  {message: "Value stored successfully"}.to_json
end

# Retrieve a value
get "/get/:key" do |env|
  key = env.params.url["key"]

  if value = REDIS.get(key)
    {key: key, value: value}.to_json
  else
    env.response.status_code = 404
    {message: "Key not found"}.to_json
  end
end

# Delete a value
delete "/:key" do |env|
  key = env.params.url["key"]

  if REDIS.del(key) > 0
    {message: "Key deleted successfully"}.to_json
  else
    env.response.status_code = 404
    {message: "Key not found"}.to_json
  end
end

# Increment a counter
post "/incr/:key" do |env|
  key = env.params.url["key"]
  new_value = REDIS.incr(key)

  {key: key, value: new_value}.to_json
end

# Store with expiration
post "/store_temp/:key" do |env|
  key = env.params.url["key"]
  value = env.params.json["value"].as(String)
  ttl = env.params.json["ttl"].as(Int64)

  REDIS.setex(key, ttl, value)
  {message: "Value stored with expiration"}.to_json
end

Kemal.run
