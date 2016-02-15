HTTP_METHODS = %w(get post put patch delete)

{% for method in HTTP_METHODS %}
  def {{method.id}}(path, &block : HTTP::Server::Context -> _)
   Kemal::RouteHandler::INSTANCE.add_route({{method}}.upcase, path, &block)
  end
{% end %}

def ws(path, &block : HTTP::WebSocket -> _)
  Kemal::WebSocketHandler.new path, &block
end

{% for type in ["before", "after"]%}
  {% for method in HTTP_METHODS %}
    def {{type.id}}_{{method.id}}(path = "*", &block : HTTP::Server::Context -> _)
     {{type.id}}({{method}}.upcase, path, &block)
    end
  {% end %}
{% end %}
