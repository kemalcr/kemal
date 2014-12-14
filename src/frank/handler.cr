require "http/server"

class Frank::Handler < HTTP::Handler
  INSTANCE = new

  def initialize
    @routes = [] of Route
  end

  def call(request)
    response = exec_request(request)
    response || call_next(request)
  end

  def add_route(method, path, &handler : Frank::Context -> _)
    @routes << Route.new(method, path, &handler)
  end

  def exec_request(request)
    components = request.path.split "/"
    @routes.each do |route|
      params = route.match(request.method, components)
      if params
        frank_request = Request.new(request, params)
        context = Context.new(frank_request)
        begin
          body = route.handler.call(context).to_s
          content_type = context.response?.try(&.content_type) || "text/plain"
          return HTTP::Response.ok(content_type, body)
        rescue ex
          return HTTP::Response.error("text/plain", ex.to_s)
        end
      end
    end
    nil
  end
end
