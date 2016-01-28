HTTP_METHODS = %w(get post put patch delete)

{% for method in HTTP_METHODS %}
  def {{method.id}}(path, &block : HTTP::Server::Context -> _)
   Kemal::Handler::INSTANCE.add_route({{method}}.upcase, path, &block)
  end
{% end %}

def ws(path, &block : HTTP::WebSocket -> _)
  Kemal::WebSocketHandler.new path, &block
end

def before(path = "*", options = {} of Symbol => String, &block : -> _)
  Kemal::Handler::INSTANCE.add_filter :before, path, options, &block
end

def after(path = "*", options = {} of Symbol => String, &block : -> _)
  Kemal::Handler::INSTANCE.add_filter :after, path, options, &block
end
