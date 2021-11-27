require "./server_config"

module Kemal
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

  # Stores all the configuration options for a Kemal application.
  # It's a singleton and you can access it like.
  #
  # ```
  # Kemal.config
  # ```
  class Config
    include ServerConfig

    @handlers = [] of HTTP::Handler
    @custom_handlers = [] of Tuple(Nil | Int32, HTTP::Handler)
    @filter_handlers = [] of HTTP::Handler
    @error_handlers = {} of Int32 => HTTP::Server::Context, Exception -> String

    property public_folder = "./public"
    property logging = true
    property always_rescue = true
    property serve_static : Hash(String, Bool) | Bool = {"dir_listing" => false, "gzip" => true}
    property static_headers : (HTTP::Server::Response, String, File::Info -> Void)?
    property powered_by_header : Bool = true
    property app_name = "Kemal"

    @logger : Kemal::BaseLogHandler?
    @error_handler : HTTP::Handler?
    @router_included = false
    @default_handlers_setup = false
    @handler_position = 0

    def logger
      @logger.not_nil!
    end

    def logger=(@logger : Kemal::BaseLogHandler)
    end

    def scheme
      ssl ? "https" : "http"
    end

    def clear
      @powered_by_header = true
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

    def add_error_handler(status_code : Int32, &handler : HTTP::Server::Context, Exception -> _)
      @error_handlers[status_code] = ->(context : HTTP::Server::Context, error : Exception) { handler.call(context, error).to_s }
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
        @handlers.insert(@handlers.size, Kemal::WebSocketHandler::INSTANCE)
        @handlers.insert(@handlers.size, Kemal::RouteHandler::INSTANCE)
      end
    end

    private def setup_init_handler
      @handlers.insert(@handler_position, Kemal::InitHandler::INSTANCE)
      @handler_position += 1
    end

    private def setup_log_handler
      @logger ||= if @logging
                    Kemal::LogHandler.new
                  else
                    Kemal::NullLogHandler.new
                  end
      @handlers.insert(@handler_position, @logger.not_nil!)
      @handler_position += 1
    end

    private def setup_error_handler
      if @always_rescue
        @error_handler ||= Kemal::ExceptionHandler.new
        @handlers.insert(@handler_position, @error_handler.not_nil!)
        @handler_position += 1
      end
    end

    private def setup_static_file_handler
      if @serve_static.is_a?(Hash)
        @handlers.insert(@handler_position, Kemal::StaticFileHandler.new(@public_folder))
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

  CONFIG = Config.new

  def self.config
    yield CONFIG
  end

  def self.config
    CONFIG
  end
end
