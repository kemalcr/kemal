<img src="https://avatars3.githubusercontent.com/u/15321198?v=3&s=200" width="100" height="100" />
# Kemal [![Build Status](https://travis-ci.org/sdogruyol/kemal.svg?branch=master)](https://travis-ci.org/sdogruyol/kemal)

[![Join the chat at https://gitter.im/sdogruyol/kemal](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/sdogruyol/kemal?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

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

# Super Fast <3

Numbers speak louder than words.

| Framework | Request Per Second  | Avg. Response Time |
| :------------ |:---------------:| -----:|
| Kemal (Production)    | 64986 | 170μs  |
| Sinatra (Thin)     | 2274        |   43.82ms |


These results were achieved with ```wrk``` on a Macbook Pro Late 2013. (**2Ghz i7 8GB Ram OS X Yosemite**)

# Installation

Kemal supports Crystal 0.9.0 and up.
You can add Kemal to your project by adding it to ```shard.yml```

```yml
name: your-app

dependencies:
  kemal:
    github: sdogruyol/kemal
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

### Browser Redirect
Just like other things in `kemal`, browser redirection is super simple as well. Use `environment` variable in defined route's corresponding block and call `redirect` on it.

```ruby
  # Redirect browser
  get "/logout" do |env|
	# important stuff like clearing session etc.
	env.redirect "/login" # redirect to /login page
  end
```

## Middlewares

You can create your own middlewares by inheriting from ```HTTP::Handler```

```crystal
class CustomHandler < HTTP::Handler
  def call(request)
    puts "Doing some custom stuff here"
    call_next request
  end
end

Kemal.config.add_handler CustomHandler.new
```

## Static Files

Kemal has built-in support for serving your static files. You need to put your static files under your ```/public``` directory.

E.g: A static file like ```/public/index.html``` will be served with the matching route ```/index.html```.

## Production / Development Mode

By default Kemal starts in ```development```mode and logs to STDOUT.

You can use ```production``` mode to redirect the output to a file. By default Kemal logs the output to ```kemal.log```.

You can start Kemal in production mode by:

```./your_app -e production```

## Thanks

Thanks to Manas for their awesome work on [Frank](https://github.com/manastech/frank).
