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

```ruby
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

```ruby
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


