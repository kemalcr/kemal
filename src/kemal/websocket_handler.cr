module Kemal
  # Kemal::WebSocketHandler is used for building a WebSocket route.
  # For each WebSocket route a new handler is created and registered to global handlers.
  class WebSocketHandler < HTTP::WebSocketHandler
    def initialize(@path : String, &@proc : HTTP::WebSocket, HTTP::Server::Context -> Void)
      Kemal.config.add_handler self
      Kemal::RouteHandler::INSTANCE.add_ws_route @path
    end

    def call(context : HTTP::Server::Context)
      return call_next(context) unless context.ws_route_defined?
      super
    end
  end
end
