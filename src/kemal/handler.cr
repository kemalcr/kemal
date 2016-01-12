require "http/server"

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
    url = request.path.not_nil!
    @routes.each do |route|
      url.match(route.pattern as Regex) do |url_params|
        request.url_params = url_params
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
end
