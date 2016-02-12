require "http/server"
require "radix"

# Kemal::RouteHandler is the main handler which handles all the HTTP requests. Routing, parsing, rendering e.g
# are done in this handler.
class Kemal::RouteHandler < HTTP::Handler
  INSTANCE = new

  def initialize
    @tree = Radix::Tree.new
  end

  def call(context)
    context.response.content_type = "text/html"
    response = process_request(context)
    response || call_next(context)
  end

  def add_route(method, path, &handler : HTTP::Server::Context -> _)
    add_to_radix_tree method, path, Route.new(method, path, &handler)

    # Registering HEAD route for defined GET routes.
    add_to_radix_tree("HEAD", path, Route.new("HEAD", path, &handler)) if method == "GET"
  end

  def process_request(context)
    url = context.request.path.not_nil!
    Kemal::Route.check_for_method_override!(context.request)
    lookup = @tree.find radix_path(context.request.override_method as String, context.request.path)
    if lookup.found?
      route = lookup.payload as Route
      context.request.url_params = lookup.params
      begin
        body = route.handler.call(context).to_s
        context.response.print body
        return context
      rescue ex
        return render_500(context, ex.to_s)
      end
    end
    # Render 404 unless a route matches
    return render_404(context)
  end

  private def radix_path(method : String, path)
    "/#{method.downcase}#{path}"
  end

  private def add_to_radix_tree(method, path, route)
    node = radix_path method, path
    @tree.add node, route
  end
end
