# Handling HTTP Request/Response

You should use `env` variable to handle HTTP Request/Response. For both `get` and `post` (and others) methods, you should use the yielded `env` object.

```ruby
# Matches /hello/kemal
  get "/hello/:name" do |env|
    name = env.params["name"]
    "Hello back to #{name}"
  end

  # Matches /resize?width=200&height=200
  get "/resize" do |env|
    width = env.params["width"]
    height = env.params["height"]
  end

  # Easily access JSON payload from the params.
  # The request content type needs to be application/json
  # The payload
  # {"name": "Serdar", "likes": ["Ruby", "Crystal"]}
  post "/json_params" do |env|
    name = env.params["name"] as String
    likes = env.params["likes"] as Array
    "#{name} likes #{likes.each.join(',')}"
  end

  # Set the content as application/json and return JSON
  get "/user.json" do |env|
    kemal = {name: "Kemal", language: "Crystal"}
    env.content_type = "application/json"
    kemal.to_json
  end

  # Add headers to your response
  get "/headers" do |env|
    env.add_header "Accept-Language", "tr"
    env.add_header "Authorization", "Token 12345"
  end
```
