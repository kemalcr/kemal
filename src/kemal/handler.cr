require "http/server"
require "uri"

# Kemal::Handler is the main handler which handles all the HTTP requests. Routing, parsing, rendering e.g
# are done in this handler.

class Kemal::Handler < HTTP::Handler
  INSTANCE = new

  def initialize
    @routes = [] of Route
  end

  def call(request)
    response = process_request(request)
    response || call_next(request)
  end

  def add_route(method, path, &handler : Kemal::Context -> _)
    @routes << Route.new(method, path, &handler)

    # Registering HEAD route for defined GET routes.
    @routes << Route.new("HEAD", path, &handler) if method == "GET"
  end

  def process_request(request)
    @routes.each do |route|
      match = route.match?(request)
      if match
        params = Kemal::ParamParser.new(route, request).parse
        context = Context.new(request, params)
        begin
          body = route.handler.call(context).to_s
          return HTTP::Response.new(context.status_code, body, context.response_headers)
        rescue ex
          return render_500(ex.to_s)
        end
      end
    end
    # Render 404 unless a route matches
    return render_404
  end
end
