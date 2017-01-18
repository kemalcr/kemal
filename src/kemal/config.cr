module Kemal
  # Kemal::Config stores all the configuration options for a Kemal application.
  # It's a singleton and you can access it like.
  #
  #   Kemal.config
  #
  class Config
    INSTANCE       = Config.new
    HANDLERS       = [] of HTTP::Handler
    ERROR_HANDLERS = {} of Int32 => HTTP::Server::Context, Exception -> String
    {% if flag?(:without_openssl) %}
    @ssl : Bool?
    {% else %}
    @ssl : OpenSSL::SSL::Context::Server?
    {% end %}

    property host_binding, ssl, port, env, public_folder, logging, running,
      always_rescue, serve_static : (Bool | Hash(String, Bool)), server, extra_options,
      shutdown_message

    def initialize
      @host_binding = "0.0.0.0"
      @port = 3000
      @env = "development"
      @serve_static = {"dir_listing" => false, "gzip" => true}
      @public_folder = "./public"
      @logging = true
      @logger = nil
      @error_handler = nil
      @always_rescue = true
      @server = uninitialized HTTP::Server
      @router_included = false
      @custom_handler_position = 4
      @default_handlers_setup = false
      @running = false
      @shutdown_message = true
    end

    def logger
      @logger.not_nil!
    end

    def logger=(logger : Kemal::BaseLogHandler)
      @logger = logger
    end

    def scheme
      ssl ? "https" : "http"
    end

    def clear
      @router_included = false
      @custom_handler_position = 4
      @default_handlers_setup = false
      HANDLERS.clear
    end

    def handlers
      HANDLERS
    end

    def add_handler(handler : HTTP::Handler | HTTP::WebSocketHandler)
      setup
      HANDLERS.insert @custom_handler_position, handler
      @custom_handler_position = @custom_handler_position + 1
    end

    def add_filter_handler(handler : HTTP::Handler)
      setup
      HANDLERS.insert HANDLERS.size - 1, handler
    end

    def error_handlers
      ERROR_HANDLERS
    end

    def add_error_handler(status_code, &handler : HTTP::Server::Context, Exception -> _)
      ERROR_HANDLERS[status_code] = ->(context : HTTP::Server::Context, error : Exception) { handler.call(context, error).to_s }
    end

    def extra_options(&@extra_options : OptionParser ->)
    end

    def setup
      unless @default_handlers_setup && @router_included
        setup_init_handler
        setup_log_handler
        setup_error_handler
        setup_static_file_handler
        @default_handlers_setup = true
        @router_included = true
        HANDLERS.insert(HANDLERS.size, Kemal::RouteHandler::INSTANCE)
      end
    end

    private def setup_init_handler
      HANDLERS.insert(0, Kemal::InitHandler::INSTANCE)
    end

    private def setup_log_handler
      @logger ||= if @logging
                    Kemal::CommonLogHandler.new
                  else
                    Kemal::NullLogHandler.new
                  end
      HANDLERS.insert(1, @logger.not_nil!)
    end

    private def setup_error_handler
      if @always_rescue
        @error_handler ||= Kemal::CommonExceptionHandler.new
        HANDLERS.insert(2, @error_handler.not_nil!)
      end
    end

    private def setup_static_file_handler
      HANDLERS.insert(3, Kemal::StaticFileHandler.new(@public_folder)) if @serve_static.is_a?(Hash)
    end
  end

  def self.config
    yield Config::INSTANCE
  end

  def self.config
    Config::INSTANCE
  end
end
