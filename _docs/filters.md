---
layout: doc
title: "Filters"
---

Before filters are evaluated before each request within the same context as the routes. They can modify the request and response.

_Important note: This should **not** be used by plugins/addons, instead they should do all their work in their own middleware._

Available filters:

 - before\_all, before\_get, before\_post, before\_put, before\_patch, before\_delete
 - after\_all, after\_get, after\_post, after\_put, after\_patch, after\_delete

The `Filter` middleware is lazily added as soon as a call to `after_X` or `before_X` is made. It will __not__ even be instantiated unless a call to `after_X` or `before_X` is made.

When using `before_all` and `after_all` keep in mind that they will be evaluated in the following order:

    before_all -> before_x -> X -> after_x -> after_all


#### Simple before_get example

```ruby
before_get "/foo" do |env|
  puts "Setting response content type"
  context.response.content_type = "application/json"
end

get "/foo" do |env|
  puts env.response.content_type # => "application/json"
  {"name": "Kemal"}.to_json
end
```

#### Simple before_all example

```ruby
before_all "/foo" do |env|
  puts "Setting response content type"
  context.response.content_type = "application/json"
end

get "/foo" do |env|
  puts env.response.content_type # => "application/json"
  {"name": "Kemal"}.to_json
end

put "/foo" do |env|
  puts env.response.content_type # => "application/json"
  {"name": "Kemal"}.to_json
end

post "/foo" do |env|
  puts env.response.content_type # => "application/json"
  {"name": "Kemal"}.to_json
end

```

#### Many blocks `before_all`

You can add many blocks to the same verb/path combination by calling it multiple times they will be called __in the same order they were defined__.

```ruby
before_all do |env|
 raise "Unauthorized" unless authorized?(env)
end

before_all do |env|
 env.session = Session.new(env.cookies)
end

get "/foo" do |env|
 "foo"
end

```

Each time `GET /foo` (or any other route since we didn't specify a route for these blocks) is called the first `before_all` will run and then the second will set the session.

_Note: `authorized?` and `Session.new` are fictitious calls used to illustrate the example._
