---
layout: doc
title: Websockets
---

Using Websockets is super easy! By nature Websockets are a bit different than standard Http Request / Response lifecycle.

You can easily create a websocket handler which matches the route of `ws://host:port/route`. You can create more than 1 websocket handler
with different routes.

```ruby
ws "/" do |socket|

end

ws "/route2" do |socket|

end
```

Let's access the socket and create a simple echo server.

```ruby
# Matches "/"
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

## Performance

Kemal has superb performance for Websockets.

Kemal

```ruby
require "kemal"

ws "/" do |socket|
  socket.on_message do |message|
  end
end
```

Node.js v4.2.1 with [ws](https://github.com/websockets/ws)

```js
var WebSocketServer = require('ws').Server
  , wss = new WebSocketServer({ port: 3000 });

wss.on('connection', function connection(ws) {
  ws.on('message', function incoming(message) {
  });

});
```

[Thor](https://github.com/observing/thor) is used to run the benchmark.

`thor -A 10000 http://localhost:3000`

| Platform | CPU Usage | Memory Usage |
| :------------ |:---------------:| -----:|
| Crystal (Kemal)    | 1.85 | 11.2 MB  |
| Node.js (ws)     | 38.95        |   906.3 MB |

This benchmark was performed on a 2013 Late Macbook Pro with 2Ghz i7 and 8G ram.

P.S: Less is better
