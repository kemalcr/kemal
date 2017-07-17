class Kemal::Base
  module Builder
    getter custom_handlers = [] of Tuple(Nil | Int32, HTTP::Handler)
    getter filter_handlers = [] of HTTP::Handler
    @handler_position = 0

    def clear
      @router_included = false
      @handler_position = 0
      @default_handlers_setup = false

      handlers.clear
      custom_handlers.clear
      filter_handlers.clear
      error_handlers.clear

      route_handler.clear
      websocket_handler.clear
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

    def add_error_handler(status_code, &handler : HTTP::Server::Context, Exception -> _)
      @error_handlers[status_code] = ->(context : HTTP::Server::Context, error : Exception) { handler.call(context, error).to_s }
    end

    def setup
      @logger = if @config.logging?
                  LogHandler.new
                else
                  NullLogHandler.new
                end
      unless @default_handlers_setup && @router_included
        setup_init_handler
        setup_log_handler
        setup_error_handler
        setup_static_file_handler
        setup_custom_handlers
        setup_filter_handlers
        @default_handlers_setup = true
        @router_included = true
        handlers.insert(handlers.size, websocket_handler)
        handlers.insert(handlers.size, route_handler)
      end
    end

    private def setup_init_handler
      @handlers.insert(@handler_position, Kemal::InitHandler.new(self))
      @handler_position += 1
    end

    private def setup_log_handler
      @handlers.insert(@handler_position, logger)
      @handler_position += 1
    end

    private def setup_error_handler
      if @config.always_rescue?
        error_handler = @error_handler ||= Kemal::ExceptionHandler.new(self)
        @handlers.insert(@handler_position, error_handler)
        @handler_position += 1
      end
    end

    private def setup_static_file_handler
      if @config.serve_static.is_a?(Hash)
        @handlers.insert(@handler_position, Kemal::StaticFileHandler.new(@config))
        @handler_position += 1
      end
    end

    # Handle WebSocketHandler
    private def setup_custom_handlers
      @custom_handlers.each do |ch|
        position = ch[0]
        if !position
          @handlers.insert(@handler_position, ch[1])
          @handler_position += 1
        else
          @handlers.insert(position, ch[1])
          @handler_position += 1
        end
      end
    end

    private def setup_filter_handlers
      @handlers.insert(@handler_position, filter_handler)
      @filter_handlers.each do |h|
        @handlers.insert(@handler_position, h)
      end
    end
  end
end
