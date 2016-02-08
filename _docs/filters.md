# Filters

Before filters are evaluated before each request within the same context as the routes will be and can modify the request and response.

```ruby
before do |env|
  puts "Setting response content type"
  context.response.content_type = "application/json"
end

get '/foo' do |env|
  puts env.response.content_type # => "application/json"
  {"name": "Kemal"}.to_json
end
```

After filters are evaluated after each request within the same context as the routes will be and can also modify the request and response

```ruby
after do |env|
  puts env.response.status
end
```
