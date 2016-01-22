require "http/server"
require "beryl/beryl/routing/tree"

# Kemal::Handler is the main handler which handles all the HTTP requests. Routing, parsing, rendering e.g
# are done in this handler.

class Kemal::Handler < HTTP::Handler
  INSTANCE = new

  def initialize
    @tree = Beryl::Routing::Tree.new
  end

  def call(request)
    response = process_request(request)
    response || call_next(request)
  end

  def add_route(method, path, &handler : Kemal::Context -> _)
    add_to_radix_tree method, path, Route.new(method, path, &handler)

    # Registering HEAD route for defined GET routes.
    add_to_radix_tree("HEAD", path, Route.new("HEAD", path, &handler)) if method == "GET"
  end

  def process_request(request)
    url = request.path.not_nil!
    Kemal::Route.check_for_method_override!(request)
    lookup = @tree.find radix_path(request.override_method, request.path)
    if lookup.found?
      route = lookup.payload as Route
      if route.match?(request)
        context = Context.new(request, route)
        begin
          body = route.handler.call(context).to_s
          return HTTP::Response.new(context.status_code, body, context.response_headers)
        rescue ex
          Kemal::Logger::INSTANCE.write "Exception: #{ex.to_s}\n"
          return render_500(ex.to_s)
        end
      end
    end
    # Render 404 unless a route matches
    return render_404
  end

  private def radix_path(method, path)
    "#{method} #{path}"
  end

  private def add_to_radix_tree(method, path, route)
    node = radix_path method, path
    @tree.add node, route
  end
end
