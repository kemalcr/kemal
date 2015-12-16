# Middlewares

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
