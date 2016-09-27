---
layout: doc
title: HTTP Request / Response Context
---

Accessing the HTTP request/response context (query params, body, content_type, headers, status_code) is super easy. You can use the context returned from the block:

```ruby
  # Matches /hello/kemal
  get "/hello/:name" do |env|
    name = env.params.url["name"]
    "Hello back to #{name}"
  end

  # Matches /resize?width=200&height=200
  get "/resize" do |env|
    width = env.params.query["width"]
    height = env.params.query["height"]
  end

  # Easily access JSON payload from the params.
  # The request content type needs to be application/json
  # The payload
  # {"name": "Serdar", "likes": ["Ruby", "Crystal"]}
  post "/json_params" do |env|
    name = env.params.json["name"] as String
    likes = env.params.json["likes"] as Array
    "#{name} likes #{likes.each.join(',')}"
  end

  # Set the content as application/json and return JSON
  get "/user.json" do |env|
    user = {name: "Kemal", language: "Crystal"}.to_json
    env.response.content_type = "application/json"
    user
  end

  # Add headers to your response
  get "/headers" do |env|
    env.response.headers["Accept-Language"] = "tr"
    env.response.headers["Authorization"] = "Token 12345"
  end
```

## Context Storage

Context is pretty useful. You can use `context` to store some variables and access them later at some point. Each stored value only exist in the lifetime of request / response cycle.
This pretty useful for sharing states between middlewares, filters e.g

```ruby
before_get "/" do |env|
  env.set "is_kemal_cool", true
end

get "/" do |env|
  is_kemal_cool = env.get "is_kemal_cool"
  "Kemal cool = #{is_kemal_cool}"
end
```

This renders `Kemal cool = true` when a request is made to `/` :)
