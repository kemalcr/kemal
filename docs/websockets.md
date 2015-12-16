# Using Websockets

Using Websockets is super easy! By nature Websockets are a bit different than standard Http Request/Response lifecycle.

You can easily create a websocket handler which matches the route of `ws://host:port/route. You can create more than 1 websocket handler
with different routes.

```ruby
  ws "/" do |socket|

  end

  ws "/route2" do |socket|

  end
```

Let's access the socket and create a simple echo server.

```ruby
  ws "/" do |socket|
    # Send welcome message to the client
    socket.send "Hello from Kemal!"

    # Handle incoming message and echo back to the client
    socket.on_message do |message|
      socket.send "Echo back from server #{message}"
    end

    # Executes when the client is disconnected. You can do the cleaning up here.
    socket.on_close do
      puts "Closing socket"
    end
  end
```
