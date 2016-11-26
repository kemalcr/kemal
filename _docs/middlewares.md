---
layout: doc
title: Middlewares
order: 9
---

## Middlewares

Middlewares a.k.a `Handler`s are the building blocks of `Kemal`. It lets you seperate your concerns into different layers.

Each middleware is supposed to have one responsibility. Take a look at `Kemal`'s built-in middlewares to see what that means.

## Creating your own middleware

You can create your own middleware by inheriting from ```Kemal::Handler```

```ruby
class CustomHandler < Kemal::Handler
  def call(context)
    puts "Doing some custom stuff here"
    call_next context
  end
end

add_handler CustomHandler.new
```

## Creating a custom Logger middleware

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

### Kemal Middlewares

Kemal organization contains some useful middlewares

- [kemal-basic-auth](https://github.com/kemalcr/kemal-basic-auth): Add HTTP Basic Authorization to your Kemal application.
- [kemal-csrf](https://github.com/kemalcr/kemal-csrf): Add CSRF protection to your Kemal application.

