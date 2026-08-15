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
      unless context.request.method == "GET"
        reject_websocket_method_not_allowed!(context)
        return
      end
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

      # Opt-in escape hatch for the previous allow-all behavior (including missing Origin).
      return true if allowed.includes?("*")

      origin_header = request.headers["Origin"]?
      return false if !origin_header || origin_header.empty?

      actual = normalize_websocket_origin(origin_header)
      return false unless actual

      if allowed.empty?
        return websocket_same_origin?(request, actual)
      end

      allowed.any? { |entry| normalize_websocket_origin(entry) == actual }
    end

    # Same-origin: Origin's host[:port] must match the request Host header.
    # Scheme is taken from the (already normalized) Origin so TLS termination in front of
    # Kemal still works — Kemal.config.scheme would be "http" in that setup.
    private def websocket_same_origin?(request : HTTP::Request, actual : String) : Bool
      return false if actual == "null"

      host = request.headers["Host"]?
      return false if !host || host.empty?

      scheme = URI.parse(actual).scheme
      return false if !scheme || scheme.empty?

      expected = normalize_websocket_origin("#{scheme}://#{host}")
      return false unless expected

      actual == expected
    end

    private def normalize_websocket_origin(origin : String) : String?
      o = origin.strip
      return if o.empty?
      return "null" if o == "null"

      uri = URI.parse(o) rescue return
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
      reject_websocket!(context, :forbidden)
    end

    # RFC 6455 §4.1 requires the opening handshake to be a GET request.
    private def reject_websocket_method_not_allowed!(context : HTTP::Server::Context)
      context.response.headers["Allow"] = "GET"
      reject_websocket!(context, :method_not_allowed)
    end

    private def reject_websocket!(context : HTTP::Server::Context, status : HTTP::Status)
      # An upstream handler (e.g. a before filter) may have already responded.
      return if context.response.closed?
      context.response.status = status
      # Close after rejection so a pipelined request cannot reuse this connection
      # (WebSocket connection smuggling via `Connection: keep-alive, Upgrade`).
      context.response.headers["Connection"] = "close"
      context.response.headers["Content-Type"] = "text/plain; charset=UTF-8"
      context.response.print status.description
    end
  end
end
