---
layout: doc
title: "Filters" 
---

Before filters are evaluated before each request within the same context as the routes. They can modify the request and response.

Available filters:
 - before_all, before_get, before_post, before_put, before_patch, before_delete
 - after_all, after_get, after_post, after_put, after_patch, after_delete

The `Filter` middleware is lazily added as soon as a call to `after_X` or `before_X` is made. It will __not__ even be instantiated unless a call to `after_X` or `before_X` is made.

When using `before_all` and `after_all` keep in mind that they will be evaluated in the following order:

    before_all -> before_x -> X -> after_x -> after_all


#### Simple before_get example

```crystal
before_get "/foo" do |env|
  puts "Setting response content type"
  context.response.content_type = "application/json"
end

get '/foo' do |env|
  puts env.response.content_type # => "application/json"
  {"name": "Kemal"}.to_json
end
```

#### Simple before_all example

```crystal
before_all "/foo" do |env|
  puts "Setting response content type"
  context.response.content_type = "application/json"
end

get '/foo' do |env|
  puts env.response.content_type # => "application/json"
  {"name": "Kemal"}.to_json
end

put '/foo' do |env|
  puts env.response.content_type # => "application/json"
  {"name": "Kemal"}.to_json
end

post '/foo' do |env|
  puts env.response.content_type # => "application/json"
  {"name": "Kemal"}.to_json
end

```

#### Many blocks `before_all`

You can add many blocks to the same verb/path combination by calling it multiple times they will be called __in the same order they were defined__.

```crystal
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
