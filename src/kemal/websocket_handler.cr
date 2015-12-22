# Kemal::WebSocketHandler is used for each define WebSocket route.
# For each WebSocket route a new handler is created and registered to global handlers.

class Kemal::WebSocketHandler < HTTP::WebSocketHandler
  def initialize(@path, &@proc : WebSocketSession ->)
    Kemal.config.add_ws_handler self
  end

  def call(request)
    return call_next(request) unless request.path.not_nil! == @path
    super
  end
end
