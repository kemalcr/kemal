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

You need to register your custom logger with `logger` macro.

```ruby
require "kemal"

logger MyCustomLogger.new
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

## Other middlewares

[kemal-pg](https://github.com/sdogruyol/kemal-pg): Postgresql Middleware for Kemal. Easily integrate Postgresql to your Kemal app.
[kemal-mysql](https://github.com/sdogruyol/kemal-mysql): Mysql Middleware for Kemal. Easily integrate Mysql to your Kemal app.
