require "net/http"

class Frank::Handler < HTTP::Handler
  INSTANCE = new

  def initialize
    @routes = [] of Route
  end

  def call(request)
    if body = exec_request(request)
      begin
        HTTP::Response.new("HTTP/1.1", 200, "OK", {"Content-Type" => "text/plain"}, body)
      rescue ex
        HTTP::Response.new("HTTP/1.1", 500, "Internal Server Error", {"Content-Type" => "text/plain"}, ex.to_s)
      end
    else
      call_next(request)
    end
  end

  def add_route(method, path, &handler : Frank::Request -> String)
    @routes << Route.new(method, path, &handler)
  end

  def exec_request(request)
    components = request.path.split "/"
    @routes.each do |route|
      params = route.match(request.method, components)
      if params
        frank_request = Request.new(params)
        return route.handler.call(frank_request)
      end
    end
    nil
  end
end
