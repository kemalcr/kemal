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
  private def paths_match?(context, dynamic_path, method)
    return true if (context.request.path === dynamic_path && !dynamic_path.includes?("*") && context.request.method == method)
    path = context.request.path + "/" unless context.request.path.ends_with?("/")
    path =~ to_path_regex dynamic_path
  end

  # Will only run rest of middleware if the current
  # path matches one of the given paths
  macro only_routes(context, paths, method = "GET")
      return call_next {{context}} unless {{paths}}.any? do |path|
        next unless Kemal::RouteHandler::INSTANCE.tree.find(radix_path({{method}}, path)).found?
        paths_match? {{context}}, path, {{method}}
      end
    end

  # Will only run rest of middleware if the current
  # path does NOT match one of the given path
  macro exclude_routes(context, paths, method = "GET")
      return call_next {{context}} if {{paths}}.any? do |path|
        next unless Kemal::RouteHandler::INSTANCE.tree.find(radix_path({{method}}, path)).found?
        paths_match? {{context}}, path, {{method}}
      end
    end
end
