require "radix"

module Kemal
  # Kemal::RouteHandler is the main handler which handles all the HTTP requests. Routing, parsing, rendering e.g
  # are done in this handler.
  class RouteHandler < HTTP::Handler
    INSTANCE = new

    property tree

    def initialize
      @tree = Radix::Tree(Route).new
    end

    def call(context)
      process_request(context)
    end

    # Adds a given route to routing tree. As an exception each `GET` route additionaly defines
    # a corresponding `HEAD` route.
    def add_route(method, path, &handler : HTTP::Server::Context -> _)
      add_to_radix_tree method, path, Route.new(method, path, &handler)
      add_to_radix_tree("HEAD", path, Route.new("HEAD", path, &handler)) if method == "GET"
    end

    # Check if a route is defined and returns the lookup
    def lookup_route(verb, path)
      @tree.find radix_path(verb, path)
    end

    # Processes the route if it's a match. Otherwise renders 404.
    def process_request(context)
      raise Kemal::Exceptions::RouteNotFound.new(context) unless context.route_defined?
      route = context.route_lookup.payload.as(Route)
      content = route.handler.call(context)
      if Kemal.config.error_handlers.has_key?(context.response.status_code)
        raise Kemal::Exceptions::CustomException.new(context)
      end
      context.response.print(content)
      context
    end

    private def radix_path(method : String, path)
      "/#{method.downcase}#{path}"
    end

    private def add_to_radix_tree(method, path, route)
      node = radix_path method, path
      @tree.add node, route
    end
  end

  # Extend HTTP::Handler so that certain macros are scoped to HTTP::Handler or
  # inheriting classes, and not part of the global scope
  class HTTP::Handler
    private def to_path_regex(path)
      path = ("^" + path + "(\/)?$").split("**")
      path = path.map { |p| p.gsub(/\*/, "[\\w\\d~]*") }
      Regex.new path.join("[\\w\\d\\/~]*")
    end

    # Checks if two routes match.
    # The second path may or may not have a single (*) or double wildcard (**)
    private def paths_match?(actual_path, dynamic_path)
      return true if (actual_path === dynamic_path && !dynamic_path.includes? "*")
      actual_path = actual_path + "/" unless actual_path.ends_with?("/")
      actual_path =~ to_path_regex dynamic_path
    end

    # Will only run rest of middleware if the current
    # route matches one of the given routes
    macro only_routes(context, routes)
      return call_next {{context}} unless {{routes}}.any? do |route|
        paths_match? {{context}}.request.path, route
      end
    end

    # Will only run rest of middleware if the current
    # route does NOT match one of the given routes
    macro exclude_routes(context, routes)
      return call_next {{context}} if {{routes}}.any? do |route|
        paths_match? {{context}}.request.path, route
      end
    end
  end
end
