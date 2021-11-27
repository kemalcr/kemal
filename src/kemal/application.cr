module Kemal
  class Application
    HTTP_METHODS   = %w(get post put patch delete options)
    FILTER_METHODS = %w(get post put patch delete options all)

    getter(init_handler) { InitHandler.new(self) }
    getter(route_handler) { RouteHandler.new(self) }
    getter(websocket_handler) { WebSocketHandler.new(self) }
    getter(filter_handler) { FilterHandler.new(self) }
    getter(config) { Config.new(self) }

    @handlers = [] of HTTP::Handler
    @custom_handlers = [] of Tuple(Nil | Int32, HTTP::Handler)
    @filter_handlers = [] of HTTP::Handler
    @error_handlers = {} of Int32 => HTTP::Server::Context, Exception -> String
    @error_handler : HTTP::Handler?
    @router_included = false
    @default_handlers_setup = false
    @handler_position = 0

    {% for method in HTTP_METHODS %}
      def {{method.id}}(path : String, &block : HTTP::Server::Context -> _)
        raise Kemal::Exceptions::InvalidPathStartException.new({{method}}, path) unless Kemal::Utils.path_starts_with_slash?(path)
        route_handler.add_route({{method}}.upcase, path, &block)
      end
    {% end %}

    def ws(path : String, &block : HTTP::WebSocket, HTTP::Server::Context -> Void)
      raise Kemal::Exceptions::InvalidPathStartException.new("ws", path) unless Kemal::Utils.path_starts_with_slash?(path)
      websocket_handler.add_route path, &block
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
          filter_handler.{{type.id}}({{method}}.upcase, path, &block)
        end

        def {{type.id}}_{{method.id}}(paths : Array(String), &block : HTTP::Server::Context -> _)
          paths.each do |path|
            filter_handler.{{type.id}}({{method}}.upcase, path, &block)
          end
        end
      {% end %}
    {% end %}

    def clear
      config.powered_by_header = true
      @router_included = false
      @handler_position = 0
      @default_handlers_setup = false
      @handlers.clear
      @custom_handlers.clear
      @filter_handlers.clear
      @error_handlers.clear
    end

    def handlers
      @handlers
    end

    def handlers=(handlers : Array(HTTP::Handler))
      clear
      @handlers.replace(handlers)
    end

    def add_handler(handler : HTTP::Handler)
      @custom_handlers << {nil, handler}
    end

    def add_handler(handler : HTTP::Handler, position : Int32)
      @custom_handlers << {position, handler}
    end

    def add_filter_handler(handler : HTTP::Handler)
      @filter_handlers << handler
    end

    def error_handlers
      @error_handlers
    end

    def setup
      unless @default_handlers_setup && @router_included
        setup_init_handler
        setup_log_handler
        setup_error_handler
        setup_static_file_handler
        setup_custom_handlers
        setup_filter_handlers
        @default_handlers_setup = true
        @router_included = true
        @handlers.insert(@handlers.size, Kemal::GLOBAL_APPLICATION.websocket_handler)
        @handlers.insert(@handlers.size, Kemal::GLOBAL_APPLICATION.route_handler)
      end
    end

    private def setup_init_handler
      @handlers.insert(@handler_position, Kemal::GLOBAL_APPLICATION.init_handler)
      @handler_position += 1
    end

    private def setup_log_handler
      @handlers.insert(@handler_position, config.logger)
      @handler_position += 1
    end

    private def setup_error_handler
      if config.always_rescue
        @error_handler ||= Kemal::ExceptionHandler.new
        @handlers.insert(@handler_position, @error_handler.not_nil!)
        @handler_position += 1
      end
    end

    private def setup_static_file_handler
      if config.serve_static.is_a?(Hash)
        @handlers.insert(@handler_position, Kemal::StaticFileHandler.new(config.public_folder))
        @handler_position += 1
      end
    end

    private def setup_custom_handlers
      @custom_handlers.each do |ch0, ch1|
        position = ch0
        @handlers.insert (position || @handler_position), ch1
        @handler_position += 1
      end
    end

    private def setup_filter_handlers
      @filter_handlers.each do |h|
        @handlers.insert(@handler_position, h)
      end
    end
  end
end
