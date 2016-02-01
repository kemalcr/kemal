---
layout: doc
title: Middlewares
---

## Built-in Middlewares

Kemal has built-in middlewares for common use cases.

### HTTP Basic Authorization

This middleware lets you add HTTP Basic Authorization to your Kemal application.
You can easily use this middleware with `basic_auth` macro like below.

```ruby
require "kemal"

basic_auth "username", "password"

get "/" do
  "This won't render without correct username and password."
end
```

## Custom middlewares

You can create your own middleware by inheriting from ```HTTP::Handler```

```ruby
class CustomHandler < HTTP::Handler
  def call(context)
    puts "Doing some custom stuff here"
    call_next context
  end
end

Kemal.config.add_handler CustomHandler.new
```

## Other middlewares

[kemal-pg](https://github.com/sdogruyol/kemal-pg): Postgresql Middleware for Kemal. Easily integrate Postgresql to your Kemal app.
