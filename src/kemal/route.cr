module Kemal
  # Route is the main building block of Kemal.
  # It takes 3 parameters: Method, path and a block to specify
  # what action to be done if the route is matched.
  class Route
    getter handler
    @handler : HTTP::Server::Context -> String
    @method : String

    def initialize(@method, @path : String, &handler : HTTP::Server::Context -> _)
      @handler = ->(context : HTTP::Server::Context) do
        handler.call(context).to_s
      end
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
