# Kemal DSL is defined here and it's baked into global scope.
#
# The DSL currently consists of:
#
# - get post put patch delete options
# - WebSocket(ws)
# - before_*
# - error
HTTP_METHODS   = %w[get post put patch delete options]
FILTER_METHODS = %w[get post put patch delete options all]

{% for method in HTTP_METHODS %}
  def {{ method.id }}(path : String, &block : HTTP::Server::Context -> _)
    raise Kemal::Exceptions::InvalidPathStartException.new({{ method }}, path) unless Kemal::Utils.path_starts_with_slash?(path)
    Kemal::RouteHandler::INSTANCE.add_route({{ method }}.upcase, path, &block)
  end
{% end %}

def ws(path : String, &block : HTTP::WebSocket, HTTP::Server::Context ->)
  raise Kemal::Exceptions::InvalidPathStartException.new("ws", path) unless Kemal::Utils.path_starts_with_slash?(path)
  Kemal::WebSocketHandler::INSTANCE.add_route path, &block
end

# Defines an error handler to be called when route returns the given HTTP status code
def error(status_code : Int32, &block : HTTP::Server::Context, Exception -> _)
  Kemal.config.add_error_handler status_code, &block
end

# Defines an error handler to be called when the given exception is raised
def error(exception : Exception.class, &block : HTTP::Server::Context, Exception -> _)
  Kemal.config.add_exception_handler exception, &block
end

# All the helper methods available are:
#  - before_all, before_get, before_post, before_put, before_patch, before_delete, before_options
#  - after_all, after_get, after_post, after_put, after_patch, after_delete, after_options
{% for type in ["before", "after"] %}
  {% for method in FILTER_METHODS %}
    def {{ type.id }}_{{ method.id }}(path : String = "*", &block : HTTP::Server::Context -> _)
     Kemal::FilterHandler::INSTANCE.{{ type.id }}({{ method }}.upcase, path, &block)
    end

    def {{ type.id }}_{{ method.id }}(paths : Array(String), &block : HTTP::Server::Context -> _)
      paths.each do |path|
        Kemal::FilterHandler::INSTANCE.{{ type.id }}({{ method }}.upcase, path, &block)
      end
    end
  {% end %}
{% end %}

# Adds a `Kemal::Handler` (middleware) to the handler chain.
# The handler runs for all requests.
#
# ```
# use MyHandler.new
# ```
def use(handler : HTTP::Handler)
  Kemal.config.add_handler(handler)
end

# Adds a `Kemal::Handler` (middleware) at a specific position in the handler chain.
#
# ```
# use MyHandler.new, 1
# ```
def use(handler : HTTP::Handler, position : Int32)
  Kemal.config.add_handler(handler, position)
end

# Adds a `Kemal::Handler` (middleware) that only runs for requests matching the path prefix.
#
# ```
# use "/api", AuthHandler.new
# use "/admin", AdminOnly.new
# ```
#
# The handler will execute for:
# - Exact match: `/api`
# - Prefix match: `/api/users`, `/api/posts/1`
#
# But NOT for:
# - `/`, `/apiv2`, `/other`
def use(path : String, handler : HTTP::Handler)
  Kemal.config.add_handler(Kemal::PathHandler.new(path, handler))
end

# Adds multiple `Kemal::Handler` (middlewares) for a specific path prefix.
#
# ```
# use "/api", [AuthHandler.new, RateLimiter.new, CorsHandler.new]
# ```
def use(path : String, handlers : Array(HTTP::Handler))
  handlers.each do |handler|
    use(path, handler)
  end
end
