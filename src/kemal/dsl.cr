# Kemal DSL is defined here and it's baked into global scope.
# These methods are available globally in your application.
#
# ## Available DSL Methods
#
# - **HTTP Routes**: `get`, `post`, `put`, `patch`, `delete`, `options`
# - **WebSocket**: `ws`
# - **Filters**: `before_all`, `before_get`, `after_all`, `after_get`, etc.
# - **Error Handling**: `error`
# - **Modular Routing**: `mount`
HTTP_METHODS   = %w[get post put patch delete options]
FILTER_METHODS = %w[get post put patch delete options all]

# Defines a route for the given HTTP method.
# The path must start with a `/`.
#
# ```
# get "/hello" do |env|
#   "Hello World!"
# end
#
# post "/users" do |env|
#   "User created"
# end
# ```
{% for method in HTTP_METHODS %}
  def {{ method.id }}(path : String, &block : HTTP::Server::Context -> _)
    raise Kemal::Exceptions::InvalidPathStartException.new({{ method }}, path) unless Kemal::Utils.path_starts_with_slash?(path)
    Kemal::RouteHandler::INSTANCE.add_route({{ method }}.upcase, path, &block)
  end
{% end %}

# Defines a WebSocket route.
# The path must start with a `/`.
#
# ```
# ws "/chat" do |socket, env|
#   socket.on_message do |msg|
#     socket.send "Echo: #{msg}"
#   end
# end
# ```
def ws(path : String, &block : HTTP::WebSocket, HTTP::Server::Context ->)
  raise Kemal::Exceptions::InvalidPathStartException.new("ws", path) unless Kemal::Utils.path_starts_with_slash?(path)
  Kemal::WebSocketHandler::INSTANCE.add_route path, &block
end

# Defines an error handler for the given HTTP status code.
#
# ```
# error 404 do |env|
#   "Page not found"
# end
# ```
def error(status_code : Int32, &block : HTTP::Server::Context, Exception -> _)
  Kemal.config.add_error_handler status_code, &block
end

# Defines an error handler for the given exception type.
#
# ```
# error MyCustomException do |env, ex|
#   "Error: #{ex.message}"
# end
# ```
def error(exception : Exception.class, &block : HTTP::Server::Context, Exception -> _)
  Kemal.config.add_exception_handler exception, &block
end

# Defines filters that run before or after requests.
#
# Available methods:
# - `before_all`, `before_get`, `before_post`, `before_put`, `before_patch`, `before_delete`, `before_options`
# - `after_all`, `after_get`, `after_post`, `after_put`, `after_patch`, `after_delete`, `after_options`
#
# ```
# before_all do |env|
#   env.response.content_type = "application/json"
# end
#
# before_get "/admin/*" do |env|
#   # Authentication check
# end
#
# # Multiple paths
# after_post ["/users", "/posts"] do |env|
#   # Logging
# end
# ```
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

# Adds a `HTTP::Handler` (middleware) to the handler chain.
# The handler runs for all requests.
#
# ```
# use MyHandler.new
# ```
def use(handler : HTTP::Handler)
  Kemal.config.add_handler(handler)
end

# Adds a `HTTP::Handler` (middleware) at a specific position in the handler chain.
#
# ```
# use MyHandler.new, position: 1
# ```
def use(handler : HTTP::Handler, position : Int32)
  Kemal.config.add_handler(handler, position)
end

# Adds a `HTTP::Handler` (middleware) that only runs for requests matching the path prefix.
#
# ```
# use "/api", AuthHandler.new
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

# Adds multiple `HTTP::Handler` (middlewares) for a specific path prefix.
#
# ```
# use "/api", [AuthHandler.new, RateLimiter.new, CorsHandler.new]
# ```
def use(path : String, handlers : Enumerable(HTTP::Handler))
  handlers.each do |handler|
    use(path, handler)
  end
end

# Mounts a router without additional prefix.
#
# ```
# api = Kemal::Router.new
# api.get "/users" do |env|
#   "users"
# end
#
# mount api
# # Result: GET /users
# ```
def mount(router : Kemal::Router)
  router.register_routes("")
end

# Mounts a router at the given path prefix.
# All routes defined in the router will be prefixed with the given path.
#
# ```
# api = Kemal::Router.new
# api.get "/users" do |env|
#   "users"
# end
#
# mount "/api/v1", api
# # Result: GET /api/v1/users
# ```
def mount(path : String, router : Kemal::Router)
  router.register_routes(path)
end
