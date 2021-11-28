require "./helpers/*"

module Kemal
  class Application
    extend Kemal::Helpers
    extend Kemal::Helpers::Macros
    extend Kemal::Helpers::Templates
    extend Kemal::Helpers::DSL
    extend Kemal::Helpers::Runner

    class_getter(init_handler) { InitHandler.new(self) }
    class_getter(route_handler) { RouteHandler.new(self) }
    class_getter(websocket_handler) { WebSocketHandler.new(self) }
    class_getter(filter_handler) { FilterHandler.new(self) }
    class_getter(config) { Config.new(self) }

    @@handlers = [] of HTTP::Handler
    @@custom_handlers = [] of Tuple(Nil | Int32, HTTP::Handler)
    @@filter_handlers = [] of HTTP::Handler
    @@error_handlers = {} of Int32 => HTTP::Server::Context, Exception -> String
    @@error_handler : HTTP::Handler?
    @@router_included = false
    @@default_handlers_setup = false
    @@handler_position = 0

    def self.clear
      config.powered_by_header = true
      @@router_included = false
      @@handler_position = 0
      @@default_handlers_setup = false
      @@handlers.clear
      @@custom_handlers.clear
      @@filter_handlers.clear
      @@error_handlers.clear
    end

    def self.handlers
      @@handlers
    end

    def self.handlers=(handlers : Array(HTTP::Handler))
      clear
      @@handlers.replace(handlers)
    end

    def self.add_handler(handler : HTTP::Handler)
      @@custom_handlers << {nil, handler}
    end

    def self.add_handler(handler : HTTP::Handler, position : Int32)
      @@custom_handlers << {position, handler}
    end

    def self.add_filter_handler(handler : HTTP::Handler)
      @@filter_handlers << handler
    end

    def self.error_handlers
      @@error_handlers
    end

    def self.setup
      unless @@default_handlers_setup && @@router_included
        setup_init_handler
        setup_log_handler
        setup_error_handler
        setup_static_file_handler
        setup_custom_handlers
        setup_filter_handlers
        @@default_handlers_setup = true
        @@router_included = true
        @@handlers.insert(@@handlers.size, websocket_handler)
        @@handlers.insert(@@handlers.size, route_handler)
      end
    end

    private def self.setup_init_handler
      @@handlers.insert(@@handler_position, init_handler)
      @@handler_position += 1
    end

    private def self.setup_log_handler
      @@handlers.insert(@@handler_position, config.logger)
      @@handler_position += 1
    end

    private def self.setup_error_handler
      if config.always_rescue
        @@error_handler ||= Kemal::ExceptionHandler.new(self)
        @@handlers.insert(@@handler_position, @@error_handler.not_nil!)
        @@handler_position += 1
      end
    end

    private def self.setup_static_file_handler
      if config.serve_static.is_a?(Hash)
        @@handlers.insert(@@handler_position, Kemal::StaticFileHandler.new(self, config.public_folder))
        @@handler_position += 1
      end
    end

    private def self.setup_custom_handlers
      @@custom_handlers.each do |ch0, ch1|
        position = ch0
        @@handlers.insert (position || @@handler_position), ch1
        @@handler_position += 1
      end
    end

    private def self.setup_filter_handlers
      @@filter_handlers.each do |h|
        @@handlers.insert(@@handler_position, h)
      end
    end
  end
end
