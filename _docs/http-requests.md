---
layout: doc
title: HTTP Request / Response Lifecycle
---

Accessing the HTTP request/response environment (query params, body, content_type, headers, status_code) is super easy. You can use the environment returned from the block:

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
    kemal = {name: "Kemal", language: "Crystal"}
    env.content_type = "application/json"
    kemal.to_json
  end

  # Add headers to your response
  get "/headers" do |env|
    env.add_header "Accept-Language", "tr"
    env.add_header "Authorization", "Token 12345"
  end
