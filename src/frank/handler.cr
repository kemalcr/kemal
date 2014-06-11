require "net/http"

class Frank::Handler < HTTP::Handler
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
      HTTP::Response.new("HTTP/1.1", 404, "Not Found", {"Content-Type" => "text/plain"}, "Not Found")
    end
  end

  def add_route(path, handler)
    @routes << Route.new(path, handler)
  end

  def exec_request(request)
    components = request.path.split "/"
    @routes.each do |route|
      frank_request = route.match(request, components)
      if frank_request
        return route.handler.call(frank_request)
      end
    end
    nil
  end
end
