# Kemal DSL is defined here and it's baked into global scope.
#
# The DSL currently consists of:
#
# - get post put patch delete options
# - WebSocket(ws)
# - before_*
# - error

{% for method in Kemal::Application::HTTP_METHODS %}
  def {{method.id}}(path : String, &block : HTTP::Server::Context -> _)
    Kemal::GLOBAL_APPLICATION.{{method.id}}(path, &block)
  end
{% end %}

def ws(path : String, &block : HTTP::WebSocket, HTTP::Server::Context -> Void)
  Kemal::GLOBAL_APPLICATION.ws(path, &block)
end

def error(status_code : Int32, &block : HTTP::Server::Context, Exception -> _)
  Kemal::GLOBAL_APPLICATION.error(status_code, &block)
end

# All the helper methods available are:
#  - before_all, before_get, before_post, before_put, before_patch, before_delete, before_options
#  - after_all, after_get, after_post, after_put, after_patch, after_delete, after_options
{% for type in ["before", "after"] %}
  {% for method in Kemal::Application::FILTER_METHODS %}
    def {{type.id}}_{{method.id}}(path : String = "*", &block : HTTP::Server::Context -> _)
     Kemal::GLOBAL_APPLICATION.{{type.id}}_{{method.id}}(path, &block)
    end

    def {{type.id}}_{{method.id}}(paths : Array(String), &block : HTTP::Server::Context -> _)
      Kemal::GLOBAL_APPLICATION.{{type.id}}_{{method.id}}(paths, &block)
    end
  {% end %}
{% end %}
