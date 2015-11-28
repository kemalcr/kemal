require "http/server"
require "uri"

class Kemal::Handler < HTTP::Handler
  INSTANCE = new

  def initialize
    @routes = [] of Route
    @match = false
  end

  def call(request)
    response = process_request(request)
    response || call_next(request)
  end

  def add_route(method, path, &handler : Kemal::Context -> _)
    @routes << Route.new(method, path, &handler)
  end

  def process_request(request)
    @routes.each do |route|
      match = route.match?(request)
      if @match = match
        params = Kemal::ParamParser.new(route, request).parse
        context = Context.new(request, params)
        begin
          body = route.handler.call(context).to_s
          return HTTP::Response.new(context.status_code, body, context.response_headers)
        rescue ex
          return HTTP::Response.error("text/plain", ex.to_s)
        end
      end
    end
    unless @match
      return HTTP::Response.new(404, not_found)
    end
    nil
  end

  def not_found
    <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <style type="text/css">
          body { text-align:center;font-family:helvetica,arial;font-size:22px;
            color:#888;margin:20px}
          #c {margin:0 auto;width:500px;text-align:left}
          </style>
        </head>
        <body>
          <h2>Kemal doesn't know this way.</h2>
          <img src="/__kemal__/404.png">
        </body>
        </html>
    HTML
  end
end
