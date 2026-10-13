module Kemal
  # Router provides modular routing capabilities for Kemal applications.
  #
  # It allows grouping routes under a common prefix and applying filters
  # to specific route groups. Routers can be nested using `namespace`.
  #
  # ## Example
  #
  # ```
  # api = Kemal::Router.new
  #
  # api.before do |env|
  #   env.response.content_type = "application/json"
  # end
  #
  # api.get "/users" do |env|
  #   User.all.to_json
  # end
  #
  # api.namespace "/admin" do
  #   get "/dashboard" do |env|
  #     {status: "ok"}.to_json
  #   end
  # end
  #
  # mount "/api/v1", api
  # ```
  class Router
    alias RouteHandler = HTTP::Server::Context -> String
    alias FilterHandler = HTTP::Server::Context -> String
    alias WSHandler = HTTP::WebSocket, HTTP::Server::Context ->
    alias SSEHandler = EventStream, HTTP::Server::Context ->

    # Stored route definition
    private record RouteDefinition,
      method : String,
      path : String,
      handler : RouteHandler

    # Stored filter definition
    private record FilterDefinition,
      type : Symbol,
      method : String,
      path : String,
      handler : FilterHandler

    # Stored websocket definition
    private record WSDefinition,
      path : String,
      handler : WSHandler

    # Stored SSE definition
    private record SSEDefinition,
      path : String,
      handler : SSEHandler

    # Stored sub-router
    private record SubRouter,
      path : String,
      router : Router

    # Path spellings that scope a filter to every route in the router:
    # `before_get` registers on "*" while `before_get "/*"` registers on "/*".
    private WILDCARD_FILTER_PATHS = {"*", "/*"}

    getter prefix : String

    @routes : Array(RouteDefinition)
    @filters : Array(FilterDefinition)
    @websockets : Array(WSDefinition)
    @sse_routes : Array(SSEDefinition)
    @sub_routers : Array(SubRouter)

    def initialize(@prefix : String = "")
      @routes = [] of RouteDefinition
      @filters = [] of FilterDefinition
      @websockets = [] of WSDefinition
      @sse_routes = [] of SSEDefinition
      @sub_routers = [] of SubRouter
    end

    # HTTP method helpers
    {% for method in HTTP_METHODS %}
      # Defines a {{ method.id.upcase }} route.
      #
      # ```
      # router.{{ method.id }} "/path" do |env|
      #   "response"
      # end
      # ```
      def {{ method.id }}(path : String, &block : HTTP::Server::Context -> _)
        add_route({{ method.upcase }}, path, &block)
      end
    {% end %}

    # Defines a WebSocket route.
    #
    # ```
    # router.ws "/chat" do |socket, env|
    #   socket.on_message do |msg|
    #     socket.send "Echo: #{msg}"
    #   end
    # end
    # ```
    #
    # NOTE: The router's `before` and `before_get` filters run for the handshake.
    # To refuse it, a filter has to `halt` or set a status an `error` handler
    # covers - a status alone still upgrades. `after` filters do not run for it.
    def ws(path : String, &block : HTTP::WebSocket, HTTP::Server::Context ->)
      @websockets << WSDefinition.new(path: path, handler: block)
    end

    # Defines a Server-Sent Events (SSE) route.
    #
    # ```
    # router.sse "/events" do |stream, env|
    #   stream.send("hello")
    # end
    # ```
    def sse(path : String, &block : EventStream, HTTP::Server::Context ->)
      @sse_routes << SSEDefinition.new(path: path, handler: block)
    end

    # Defines a before filter for all HTTP methods.
    #
    # ```
    # router.before do |env|
    #   env.response.content_type = "application/json"
    # end
    # ```
    def before(path : String = "*", &block : HTTP::Server::Context -> _)
      add_filter(:before, "ALL", path, &block)
    end

    # Defines an after filter for all HTTP methods.
    #
    # ```
    # router.after do |env|
    #   puts "Request completed"
    # end
    # ```
    def after(path : String = "*", &block : HTTP::Server::Context -> _)
      add_filter(:after, "ALL", path, &block)
    end

    # Method-specific before/after filters
    {% for method in FILTER_METHODS %}
      # Defines a before filter for {{ method.id.upcase }} requests.
      def before_{{ method.id }}(path : String = "*", &block : HTTP::Server::Context -> _)
        add_filter(:before, {{ method.upcase }}, path, &block)
      end

      # Defines an after filter for {{ method.id.upcase }} requests.
      def after_{{ method.id }}(path : String = "*", &block : HTTP::Server::Context -> _)
        add_filter(:after, {{ method.upcase }}, path, &block)
      end
    {% end %}

    # Creates a nested namespace/group with the given *path* prefix.
    #
    # NOTE: The path must start with a `/`.
    #
    # All routes defined inside the block will be prefixed with the given path.
    #
    # ```
    # router.namespace "/users" do
    #   get "/" do |env|
    #     User.all.to_json
    #   end
    #
    #   get "/:id" do |env|
    #     User.find(env.params.url["id"]).to_json
    #   end
    # end
    # ```
    def namespace(path : String, &)
      sub_router = Router.new
      with sub_router yield
      @sub_routers << SubRouter.new(path: path, router: sub_router)
    end

    # Mounts another router at the given *path* prefix.
    #
    # NOTE: The path must start with a `/`.
    #
    # ```
    # users_router = Kemal::Router.new
    # users_router.get "/" { |env| "users" }
    #
    # api = Kemal::Router.new
    # api.mount "/users", users_router
    #
    # mount "/api", api
    # # Result: GET /api/users
    # ```
    def mount(path : String, router : Router)
      @sub_routers << SubRouter.new(path: path, router: router)
    end

    # Mounts another router without additional prefix.
    def mount(router : Router)
      mount("", router)
    end

    # Registers all routes, filters, and websockets with Kemal's handlers.
    # This is called automatically when using `mount` from DSL.
    #
    # Each route carries the filters of this router and of every router it is
    # mounted under, so they run for exactly the requests the router's routes
    # serve. They used to be registered by path in `Kemal::FilterHandler`'s
    # radix tree, which runs only the best match for a request path: a router's
    # `ws` routes were never collected there, and a more specific key from
    # anywhere else hid a router's filters - a guard that silently did not run.
    #
    # :nodoc:
    def register_routes(base_prefix : String = "", parent_filters = [] of {String, String, Kemal::FilterHandler::FilterBlock})
      full_prefix = join_paths(base_prefix, @prefix)
      filters = parent_filters + @filters.map do |filter|
        {filter.method, Kemal::FilterHandler.filter_key(filter.method, filter.type), filter_block(full_prefix, filter)}
      end
      Kemal::FilterHandler::INSTANCE.register_router_filters unless filters.empty?
      # Routes with the same method carry the same filters.
      scoped = Hash(String, Kemal::FilterHandler::ScopedFilters?).new { |hash, method| hash[method] = scoped_filters(filters, method) }

      # Register routes
      @routes.each do |route|
        full_path = join_paths(full_prefix, route.path)
        validate_path!(route.method.downcase, full_path)
        Kemal::RouteHandler::INSTANCE.add_route(route.method, full_path, scoped[route.method]) do |env|
          route.handler.call(env)
        end
      end

      # Register websockets
      @websockets.each do |ws_def|
        full_path = join_paths(full_prefix, ws_def.path)
        validate_path!("ws", full_path)
        Kemal::WebSocketHandler::INSTANCE.add_route(full_path, scoped["GET"], &ws_def.handler)
      end

      # Register SSE routes
      @sse_routes.each do |sse_def|
        full_path = join_paths(full_prefix, sse_def.path)
        validate_path!("sse", full_path)
        Kemal::RouteHandler::INSTANCE.add_route("GET", full_path, scoped["GET"]) do |env|
          Kemal::EventStream.serve(env, &sse_def.handler)
        end
      end

      # Register sub-routers recursively
      @sub_routers.each do |sub|
        sub_prefix = join_paths(full_prefix, sub.path)
        sub.router.register_routes(sub_prefix, filters)
      end
    end

    # The filters among *filters* - `{method, key, block}`, outer routers first,
    # each in definition order - that a *method* route runs.
    private def scoped_filters(filters : Array({String, String, Kemal::FilterHandler::FilterBlock}), method : String) : Kemal::FilterHandler::ScopedFilters?
      scoped = nil
      filters.each do |filter_method, key, block|
        next unless filter_method.in?("ALL", method)

        scoped ||= Kemal::FilterHandler::ScopedFilters.new
        (scoped[key] ||= [] of Kemal::FilterHandler::FilterBlock) << block
      end
      scoped
    end

    # A filter with a path runs for requests to that path and below it, matched
    # against the request path when the request comes in. Comparing it with the
    # router's route paths when the routes are registered missed every request
    # whose path differs from the route's spelling: `before "/users/:id"` and a
    # `get "/users/me"`, `before "/users/admin"` and a `get "/users/:id"`, a
    # named glob, a trailing slash - each a guard that silently did not run.
    private def filter_block(prefix : String, filter : FilterDefinition) : Kemal::FilterHandler::FilterBlock
      return Kemal::FilterHandler::FilterBlock.new(&filter.handler) if WILDCARD_FILTER_PATHS.includes?(filter.path)

      pattern = filter_pattern(join_paths(prefix, filter.path.rchop("/*")))
      Kemal::FilterHandler::FilterBlock.new do |env|
        filter.handler.call(env) if pattern.matches?(env.request.path)
      end
    end

    # `:param` matches one segment and `*glob` the rest, as in a route path.
    private def filter_pattern(scope : String) : Regex
      source = scope.chomp('/').split('/').join('/') do |segment|
        case segment[0]?
        when ':' then "[^/]+"
        when '*' then ".*"
        else          Regex.escape(segment)
        end
      end
      Regex.new("\\A#{source}(?:/.*)?\\z")
    end

    private def add_route(method : String, path : String, &block : HTTP::Server::Context -> _)
      handler = ->(ctx : HTTP::Server::Context) do
        result = block.call(ctx)
        result.is_a?(String) ? result : ""
      end
      @routes << RouteDefinition.new(method: method, path: path, handler: handler)
    end

    private def add_filter(type : Symbol, method : String, path : String, &block : HTTP::Server::Context -> _)
      handler = ->(ctx : HTTP::Server::Context) do
        result = block.call(ctx)
        result.is_a?(String) ? result : ""
      end
      @filters << FilterDefinition.new(type: type, method: method, path: path, handler: handler)
    end

    private def join_paths(a : String, b : String) : String
      a = a.chomp('/')
      b = b.lchop('/') if b.starts_with?('/')
      return "/#{b}" if a.empty?
      return a if b.empty?
      "#{a}/#{b}"
    end

    private def validate_path!(method : String, path : String)
      unless Utils.path_starts_with_slash?(path)
        raise Exceptions::InvalidPathStartException.new(method, path)
      end
    end
  end
end
