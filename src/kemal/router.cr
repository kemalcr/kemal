module Kemal
  # Router provides modular routing capabilities for Kemal applications.
  #
  # It allows grouping routes under a common prefix and applying filters
  # to specific route groups. Routers can be nested using `namespace` or `group`.
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

    # Stored sub-router
    private record SubRouter,
      path : String,
      router : Router

    getter prefix : String

    @routes : Array(RouteDefinition)
    @filters : Array(FilterDefinition)
    @websockets : Array(WSDefinition)
    @sub_routers : Array(SubRouter)

    def initialize(@prefix : String = "")
      @routes = [] of RouteDefinition
      @filters = [] of FilterDefinition
      @websockets = [] of WSDefinition
      @sub_routers = [] of SubRouter
    end

    # HTTP method helpers
    {% for method in %w[get post put patch delete options] %}
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
    def ws(path : String, &block : HTTP::WebSocket, HTTP::Server::Context ->)
      @websockets << WSDefinition.new(path: path, handler: block)
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
    {% for method in %w[get post put patch delete options all] %}
      # Defines a before filter for {{ method.id.upcase }} requests.
      def before_{{ method.id }}(path : String = "*", &block : HTTP::Server::Context -> _)
        add_filter(:before, {{ method.upcase }}, path, &block)
      end

      # Defines an after filter for {{ method.id.upcase }} requests.
      def after_{{ method.id }}(path : String = "*", &block : HTTP::Server::Context -> _)
        add_filter(:after, {{ method.upcase }}, path, &block)
      end
    {% end %}

    # Creates a nested namespace/group with the given path prefix.
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

    # Alias for `namespace`. Creates a nested namespace/group with the given path prefix.
    def group(path : String, &)
      sub_router = Router.new
      with sub_router yield
      @sub_routers << SubRouter.new(path: path, router: sub_router)
    end

    # Mounts another router at the given path prefix.
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
    # :nodoc:
    def register_routes(base_prefix : String = "")
      full_prefix = join_paths(base_prefix, @prefix)

      # Collect all route paths for filter registration
      route_paths = collect_all_route_paths(full_prefix)

      # Register filters for each route path
      register_filters(full_prefix, route_paths)

      # Register routes
      @routes.each do |route|
        full_path = join_paths(full_prefix, route.path)
        validate_path!(route.method.downcase, full_path)
        Kemal::RouteHandler::INSTANCE.add_route(route.method, full_path) do |env|
          route.handler.call(env)
        end
      end

      # Register websockets
      @websockets.each do |ws_def|
        full_path = join_paths(full_prefix, ws_def.path)
        validate_path!("ws", full_path)
        Kemal::WebSocketHandler::INSTANCE.add_route(full_path, &ws_def.handler)
      end

      # Register sub-routers recursively
      @sub_routers.each do |sub|
        sub_prefix = join_paths(full_prefix, sub.path)
        sub.router.register_routes(sub_prefix)
      end
    end

    # Collect all route paths including sub-routers
    # :nodoc:
    protected def collect_all_route_paths(full_prefix : String) : Array(Tuple(String, String))
      paths = [] of Tuple(String, String)

      # This router's routes
      @routes.each do |route|
        full_path = join_paths(full_prefix, route.path)
        paths << {route.method, full_path}
      end

      # Sub-router routes
      @sub_routers.each do |sub|
        sub_prefix = join_paths(full_prefix, sub.path)
        paths.concat(sub.router.collect_all_route_paths(sub_prefix))
      end

      paths
    end

    # Register filters for specific route paths
    private def register_filters(full_prefix : String, route_paths : Array(Tuple(String, String)))
      return if @filters.empty?

      # Ensure FilterHandler is registered with Kemal (may have been cleared between tests)
      unless Kemal::Config::FILTER_HANDLERS.includes?(Kemal::FilterHandler::INSTANCE)
        Kemal.config.add_filter_handler(Kemal::FilterHandler::INSTANCE)
      end

      @filters.each do |filter|
        # Determine which paths this filter applies to
        applicable_paths = if filter.path == "*"
                             # Apply to all routes in this router
                             route_paths
                           else
                             # Apply to specific path
                             filter_full_path = join_paths(full_prefix, filter.path)
                             route_paths.select { |_, path| path == filter_full_path || path.starts_with?(filter_full_path + "/") }
                           end

        applicable_paths.each do |route_method, route_path|
          # Check if filter method matches route method
          next unless filter.method == "ALL" || filter.method == route_method

          # Use filter's method (ALL or specific) when registering
          register_method = filter.method

          case filter.type
          when :before
            Kemal::FilterHandler::INSTANCE.before(register_method, route_path) do |env|
              filter.handler.call(env)
            end
          when :after
            Kemal::FilterHandler::INSTANCE.after(register_method, route_path) do |env|
              filter.handler.call(env)
            end
          end
        end
      end
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
      a = a.chomp("/")
      b = b.lchop("/") if b.starts_with?("/")
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
