module Kemal
  # Kemal::WebSocketHandler is used for building a WebSocket route.
  # For each WebSocket route a new handler is created and registered to global handlers.
  class WebSocketHandler < HTTP::WebSocketHandler
    def initialize(@path : String, &@proc : HTTP::WebSocket, HTTP::Server::Context -> Void)
      Kemal.config.add_handler self
    end

    def call(context)
      return call_next(context) unless context.request.path.not_nil! == @path
      super
    end
  end
end
