# Kemal DSL is defined here and it's baked into global scope.
#
# The DSL currently consists of:
#
# - get post put patch delete options
# - WebSocket(ws)
# - before_*
# - error

{% for method in Kemal::Base::HTTP_METHODS %}
  def {{method.id}}(path, &block : HTTP::Server::Context -> _)
    Kemal.application.{{method.id}}(path, &block)
  end
{% end %}

def ws(path, &block : HTTP::WebSocket, HTTP::Server::Context -> Void)
  Kemal.application.ws(path, &block)
end

def error(status_code, &block : HTTP::Server::Context, Exception -> _)
  Kemal.application.add_error_handler status_code, &block
end

# All the helper methods available are:
#  - before_all, before_get, before_post, before_put, before_patch, before_delete, before_options
#  - after_all, after_get, after_post, after_put, after_patch, after_delete, after_options
{% for type in ["before", "after"] %}
  {% for method in Kemal::Base::FILTER_METHODS %}
    def {{type.id}}_{{method.id}}(path = "*", &block : HTTP::Server::Context -> _)
     Kemal.application.{{type.id}}_{{method.id}}(path, &block)
    end
  {% end %}
{% end %}
