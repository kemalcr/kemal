require "radix"

module Kemal
  class RouteHandler
    include HTTP::Handler

    INSTANCE            = new
    CACHED_ROUTES_LIMIT = 1024
    property routes, cached_routes

    def initialize
      @routes = Radix::Tree(Route).new
      @cached_routes = Hash(String, Radix::Result(Route)).new
    end

    def call(context : HTTP::Server::Context)
      process_request(context)
    end

    # Adds a given route to routing tree.
    def add_route(method : String, path : String, &handler : HTTP::Server::Context -> _)
      add_to_radix_tree method, path, Route.new(method, path, &handler)
    end

    # Looks up the route from the Radix::Tree for the first time and caches to improve performance.
    def lookup_route(verb : String, path : String)
      lookup_path = radix_path(verb, path)

      if cached_route = @cached_routes[lookup_path]?
        return cached_route
      end

      route = @routes.find(lookup_path)

      if verb == "HEAD" && !route.found?
        # On HEAD requests, implicitly fallback to running the GET handler.
        route = @routes.find(radix_path("GET", path))
      end

      if route.found?
        @cached_routes.clear if @cached_routes.size == CACHED_ROUTES_LIMIT
        @cached_routes[lookup_path] = route
      end

      route
    end

    # Processes the route if it's a match. Otherwise renders 404.
    private def process_request(context)
      raise Kemal::Exceptions::RouteNotFound.new(context) unless context.route_found?
      return if context.response.closed?
      content = context.route.handler.call(context)

      if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(context.response.status_code)
        raise Kemal::Exceptions::CustomException.new(context)
      end

      context.response.print(content)
      context
    end

    private def radix_path(method, path)
      '/' + method + path
    end

    private def add_to_radix_tree(method, path, route)
      node = radix_path method, path
      @routes.add node, route
    end
  end
end
