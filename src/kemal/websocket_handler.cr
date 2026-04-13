module Kemal
  class WebSocketHandler
    include HTTP::Handler

    INSTANCE = new
    property routes

    def initialize
      @routes = Radix::Tree(WebSocket).new
    end

    def call(context : HTTP::Server::Context)
      return call_next(context) unless context.ws_route_found? && websocket_upgrade_request?(context)
      unless websocket_origin_allowed?(context.request)
        reject_websocket_forbidden!(context)
        return
      end
      context.websocket.call(context)
    end

    def lookup_ws_route(path : String)
      @routes.find "/ws" + path
    end

    def add_route(path : String, &handler : HTTP::WebSocket, HTTP::Server::Context ->)
      add_to_radix_tree path, WebSocket.new(path, &handler)
    end

    private def add_to_radix_tree(path, websocket)
      node = radix_path "ws", path
      @routes.add node, websocket
    end

    private def radix_path(method, path)
      '/' + method.downcase + path
    end

    private def websocket_upgrade_request?(context)
      return unless upgrade = context.request.headers["Upgrade"]?
      return unless upgrade.compare("websocket", case_insensitive: true) == 0

      context.request.headers.includes_word?("Connection", "Upgrade")
    end

    private def websocket_origin_allowed?(request : HTTP::Request) : Bool
      allowed = Kemal.config.websocket_allowed_origins
      return true if allowed.empty?

      origin_header = request.headers["Origin"]?
      return false if !origin_header || origin_header.empty?

      actual = normalize_websocket_origin(origin_header)
      return false unless actual

      allowed.any? { |entry| normalize_websocket_origin(entry) == actual }
    end

    private def normalize_websocket_origin(origin : String) : String?
      o = origin.strip
      return if o.empty?
      return "null" if o == "null"

      uri = URI.parse(o)
      scheme_raw = uri.scheme
      host_raw = uri.host
      return unless scheme_raw && host_raw

      scheme = scheme_raw.downcase
      host = host_raw.downcase
      port = uri.port
      default = URI.default_port(scheme)
      if port && default && port == default
        "#{scheme}://#{host}"
      elsif port
        "#{scheme}://#{host}:#{port}"
      else
        "#{scheme}://#{host}"
      end
    end

    private def reject_websocket_forbidden!(context : HTTP::Server::Context)
      context.response.status_code = 403
      context.response.headers["Content-Type"] = "text/plain; charset=UTF-8"
      context.response.print "Forbidden"
    end
  end
end
