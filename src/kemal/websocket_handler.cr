class Kemal::WebsocketHandler < HTTP::WebSocketHandler
  def initialize(@path, &@proc : WebSocketSession ->)
    Kemal.config.add_ws_handler self
  end

  def call(request)
    return call_next(request) unless request.path.not_nil! == @path
    super
  end
end
