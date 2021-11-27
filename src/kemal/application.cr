module Kemal
  class Application
    HTTP_METHODS   = %w(get post put patch delete options)
    FILTER_METHODS = %w(get post put patch delete options all)

    getter(init_handler) { InitHandler.new(self) }
    getter(route_handler) { RouteHandler.new(self) }
    getter(websocket_handler) { WebSocketHandler.new(self) }
    getter(filter_handler) { FilterHandler.new(self) }
    getter error_handler = {} of Int32 => HTTP::Server::Context, Exception -> String

    {% for method in HTTP_METHODS %}
      def {{method.id}}(path : String, &block : HTTP::Server::Context -> _)
        raise Kemal::Exceptions::InvalidPathStartException.new({{method}}, path) unless Kemal::Utils.path_starts_with_slash?(path)
        @route_handler.add_route({{method}}.upcase, path, &block)
      end
    {% end %}

    def ws(path : String, &block : HTTP::WebSocket, HTTP::Server::Context -> Void)
      raise Kemal::Exceptions::InvalidPathStartException.new("ws", path) unless Kemal::Utils.path_starts_with_slash?(path)
      @websocket_handler.add_route path, &block
    end

    def error(status_code : Int32, &block : HTTP::Server::Context, Exception -> _)
      @error_handlers[status_code] = ->(context : HTTP::Server::Context, error : Exception) { block.call(context, error).to_s }
    end

    # All the helper methods available are:
    #  - before_all, before_get, before_post, before_put, before_patch, before_delete, before_options
    #  - after_all, after_get, after_post, after_put, after_patch, after_delete, after_options
    {% for type in ["before", "after"] %}
      {% for method in FILTER_METHODS %}
        def {{type.id}}_{{method.id}}(path : String = "*", &block : HTTP::Server::Context -> _)
          @filter_handler.{{type.id}}({{method}}.upcase, path, &block)
        end

        def {{type.id}}_{{method.id}}(paths : Array(String), &block : HTTP::Server::Context -> _)
          paths.each do |path|
            @filter_handler.{{type.id}}({{method}}.upcase, path, &block)
          end
        end
      {% end %}
    {% end %}
  end
end
