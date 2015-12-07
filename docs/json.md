# Serving JSON API

You need to return a ```JSON``` object or need to convert the existing object via `to_json`.

```ruby
require "kemal"
require "json"

# You can easily access the context and set content_type like 'application/json'.
# Look how easy to build a JSON serving API.
get "/" do |env|
  env.content_type = "application/json"
  {name: "Serdar", age: 27}.to_json
end

```
