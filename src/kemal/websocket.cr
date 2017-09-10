module Kemal
  # Route is the main building block of Kemal.
  # It takes 3 parameters: Method, path and a block to specify
  # what action to be done if the route is matched.
  class WebSocket < HTTP::WebSocketHandler
    getter proc

    def initialize(@path : String, &@proc : HTTP::WebSocket, HTTP::Server::Context -> Void)
    end

    def call(context : HTTP::Server::Context)
      super
    end
  end
end
