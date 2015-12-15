class Kemal::WebsocketHandler < HTTP::WebSocketHandler
  getter handler

  def initialize(@path, &@proc : WebSocketSession ->)
    @handler = @proc
    Kemal.config.add_ws_handler self
  end

  def call(request)
    return call_next(request) unless request.path.not_nil! == @path
    super
  end
end
