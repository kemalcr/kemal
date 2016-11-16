# Kemal DSL is defined here and it's baked into global scope.
# The DSL currently consists of HTTP verbs(get post put patch delete options),
# WebSocket(ws) and custom error handler(error).
HTTP_METHODS = %w(get post put patch delete options)

{% for method in HTTP_METHODS %}
  def {{method.id}}(path, &block : HTTP::Server::Context -> _)
  	raise Kemal::Exceptions::InvalidPathStartException.new({{method}}, path) unless Kemal::Utils.path_starts_with_backslash?(path)
    Kemal::RouteHandler::INSTANCE.add_route({{method}}.upcase, path, &block)
  end
{% end %}

def ws(path, &block : HTTP::WebSocket, HTTP::Server::Context -> Void)
  raise Kemal::Exceptions::InvalidPathStartException.new("ws", path) unless Kemal::Utils.path_starts_with_backslash?(path)
  Kemal::WebSocketHandler.new path, &block
end

def error(status_code, &block : HTTP::Server::Context, Exception -> _)
  Kemal.config.add_error_handler status_code, &block
end
