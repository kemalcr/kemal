<img src="https://avatars3.githubusercontent.com/u/15321198?v=3&s=200" width="100" height="100" />
# Kemal

Lightning Fast, Super Simple web framework for [Crystal](http://www.crystal-lang.org).
Inspired by [Sinatra](http://www.sinatrarb.com/)

Kemal is under heavy development and currently supports Crystal 0.9.0.

# Super Simple <3

```ruby
require "kemal"

get "/" do
  "Hello World!"
end
```

Build and run!

```
crystal build --release src/kemal_sample.cr
./kemal_sample
```
Go to *http://localhost:3000*

Check [samples](https://github.com/kemalcr/kemal/tree/master/samples) for more.

# Installation

Add it to your ```shard.yml```

```yml
dependencies:
  kemal:
    github: kemalcr/kemal
    branch: master
```

## Routes

In Kemal, a route is an HTTP method paired with a URL-matching pattern. Each route is associated with a block:

```ruby
  get "/" do
  .. show something ..
  end

  post "/" do
  .. create something ..
  end

  put "/" do
  .. replace something ..
  end

  patch "/" do
  .. modify something ..
  end

  delete "/" do
  .. annihilate something ..
  end  
```

## Context

Accessing the request context (query params, body, headers e.g) is super easy. You can use the context returned from the block:

```ruby
  # Matches /hello/kemal
  get "/hello/:name" do |ctx|
    name = ctx.params["name"]
    "Hello back to #{name}"
  end

  # Matches /resize?width=200&height=200
  get "/resize" do |ctx|
    width = ctx.params["width"]
    height = ctx.params["height"]
  end
```

## Content Type
Kemal uses *text/html* as the default content type. You can change it via the context.

```ruby
  # Set the content as application/json and return JSON
  get "/user.json" do |ctx|
    kemal = {name: "Kemal", language: "Crystal"}
    ctx.set_content_type "application/json"
    kemal.to_json
  end
```

## Thanks

Thanks to Manas for their awesome work on [Frank](https://github.com/manastech/frank).
