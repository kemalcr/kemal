require "kemal"
require "json"

# You can easily access the environment and set content_type like 'application/json'.
# Look how easy to build a JSON serving API.
get "/" do |env|
  env.response.content_type = "application/json"
  {name: "Serdar", age: 27}.to_json
end
