---
layout: doc
title: Middlewares
---

# Middlewares

You can create your own middlewares by inheriting from ```HTTP::Handler```

```ruby
class CustomHandler < HTTP::Handler
  def call(request)
    puts "Doing some custom stuff here"
    call_next request
  end
end

Kemal.config.add_handler CustomHandler.new
```
