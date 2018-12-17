require "radix"

module Kemal
  class RouteHandler
    include HTTP::Handler

    INSTANCE            = new
    CACHED_ROUTES_LIMIT = 1024
    property routes, cached_routes

    getter app : Kemal::Base

    def initialize(@app)
      @routes = Radix::Tree(Route).new
      @cached_routes = Hash(String, Radix::Result(Route)).new
    end

    def call(context : HTTP::Server::Context)
      process_request(context)
    end

    # Adds a given route to routing tree. As an exception each `GET` route additionaly defines
    # a corresponding `HEAD` route.
    def add_route(method : String, path : String, &handler : HTTP::Server::Context -> _)
      add_to_radix_tree method, path, Route.new(method, path, &handler)
      add_to_radix_tree("HEAD", path, Route.new("HEAD", path) { }) if method == "GET"
    end

    # Looks up the route from the Radix::Tree for the first time and caches to improve performance.
    def lookup_route(verb : String, path : String)
      lookup_path = radix_path(verb, path)

      if cached_route = @cached_routes[lookup_path]?
        return cached_route
      end

      route = @routes.find(lookup_path)

      if route.found?
        @cached_routes.clear if @cached_routes.size == CACHED_ROUTES_LIMIT
        @cached_routes[lookup_path] = route
      end

      route
    end

    def lookup_route(request)
      lookup_route request.override_method.as(String), request.path
    end

    def route_defined?(request)
      lookup_route(request).found?
    end

    # Processes the route if it's a match. Otherwise renders 404.
    private def process_request(context)
      raise Kemal::Exceptions::RouteNotFound.new(context) unless route_defined?(context.request)

      tree_result = lookup_route(context.request)
      context.request.url_params = tree_result.params
      content = tree_result.payload.handler.call(context)

      if !app.error_handlers.empty? && app.error_handlers.has_key?(context.response.status_code)
        raise Kemal::Exceptions::CustomException.new(context)
      end

      context.response.print(content)
      context
    end

    private def radix_path(method, path)
      '/' + method.downcase + path
    end

    private def add_to_radix_tree(method, path, route)
      node = radix_path method, path
      @routes.add node, route
    end

    def clear
      @routes = Radix::Tree(Route).new
      @cached_routes = Hash(String, Radix::Result(Route)).new
    end
  end
end
