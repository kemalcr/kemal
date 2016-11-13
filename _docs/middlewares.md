---
layout: doc
title: Middlewares
---

## Middlewares

Middlewares a.k.a `Handler`s are the building blocks of `Kemal`. It lets you seperate your concerns into different layers. 

Each middleware is supposed to have one responsibility. Take a look at `Kemal`'s built-in middlewares to see what that means.

### Built-in Middlewares

#### HTTP Basic Authorization

This middleware lets you add HTTP Basic Authorization to your Kemal application.
You can easily use this middleware with `basic_auth` macro like below.

```ruby
require "kemal"

basic_auth "username", "password"

get "/" do
  "This won't render without correct username and password."
end

Kemal.run
```

### CSRF

This middleware adds CSRF protection to your application.

Returns 403 "Forbidden" unless the current CSRF token is submitted
with any non-GET/HEAD request.

Without CSRF protection, your app is vulnerable to replay attacks
where an attacker can re-submit a form.

```ruby
csrf_handler = Kemal::Middleware::CSRF.new
Kemal.config.add_handler csrf_handler
```

## Custom Logger

You can easily replace the built-in logger of `Kemal`. There's only one requirement which is that
your logger must inherit from `Kemal::BaseLogHandler`.

```ruby
class MyCustomLogger < Kemal::BaseLogHandler
  # This is run for each request. You can access the request/response context with `context`.
  def call(context)
    puts "Custom logger is in action."
    # Be sure to `call_next`.
    call_next context
  end

  def write(message)
  end
end
```

You need to register your custom logger with `logger` config property.

```ruby
require "kemal"

Kemal.config.logger = MyCustomLogger.new(Kemal.config.env)
...
```

That's it!

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

