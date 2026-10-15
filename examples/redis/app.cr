require "kemal"
require "redis"

# Initialize Redis client
REDIS = Redis.new(host: "localhost", port: 6379)

# Prefix every key so clients can only reach this example's keys,
# not sessions or other data that share the same Redis
def redis_key(key : String) : String
  "kemal-example:#{key}"
end

# Store a value
post "/store/:key" do |env|
  key = env.params.url["key"]
  value = env.params.json["value"].as(String)

  REDIS.set(redis_key(key), value)
  {message: "Value stored successfully"}.to_json
end

# Retrieve a value
get "/get/:key" do |env|
  key = env.params.url["key"]

  if value = REDIS.get(redis_key(key))
    {key: key, value: value}.to_json
  else
    env.response.status_code = 404
    {message: "Key not found"}.to_json
  end
end

# Delete a value
delete "/store/:key" do |env|
  key = env.params.url["key"]

  if REDIS.del(redis_key(key)) > 0
    {message: "Key deleted successfully"}.to_json
  else
    env.response.status_code = 404
    {message: "Key not found"}.to_json
  end
end

# Increment a counter
post "/incr/:key" do |env|
  key = env.params.url["key"]
  new_value = REDIS.incr(redis_key(key))

  {key: key, value: new_value}.to_json
end

# Store with expiration
post "/store_temp/:key" do |env|
  key = env.params.url["key"]
  value = env.params.json["value"].as(String)
  ttl = env.params.json["ttl"].as(Int64)

  REDIS.setex(redis_key(key), ttl, value)
  {message: "Value stored with expiration"}.to_json
end

Kemal.run
