module Kemal
  class WebSocketHandler
    include HTTP::Handler

    property routes = Radix::Tree(WebSocket).new

    def initialize(app : Kemal::Application)
    end

    def call(context : HTTP::Server::Context)
      lookup_result = lookup_ws_route(context.request.path)
      if lookup_result.found? && websocket_upgrade_request?(context)
        context.ws_params = lookup_result.params
        lookup_result.payload.call(context)
      else
        call_next(context)
      end
    end

    def lookup_ws_route(path : String)
      @routes.find "/ws" + path
    end

    def add_route(path : String, &handler : HTTP::WebSocket, HTTP::Server::Context -> Void)
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
  end
end
