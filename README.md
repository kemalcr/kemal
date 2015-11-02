<img src="https://avatars3.githubusercontent.com/u/15321198?v=3&s=200" width="100" height="100" />
# Kemal
[![Build Status](https://travis-ci.org/kemalcr/kemal.svg?branch=master)](https://travis-ci.org/kemalcr/kemal)

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

## Environment

Accessing the environment (query params, body, content_type, headers, status_code) is super easy. You can use the environment returned from the block:

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

## Static Files

Kemal has built-in support for serving your static files. You need to put your static files under your ```/public``` directory.

E.g: A static file like ```/public/index.html``` will be served with the matching route ```/index.html```.

## Thanks

Thanks to Manas for their awesome work on [Frank](https://github.com/manastech/frank).
