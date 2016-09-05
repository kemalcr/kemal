module Kemal
  # Kemal::Config stores all the configuration options for a Kemal application.
  # It's a singleton and you can access it like.
  #
  #   Kemal.config
  #
  class Config
    INSTANCE       = Config.new
    HANDLERS       = [] of HTTP::Handler
    ERROR_HANDLERS = {} of Int32 => HTTP::Server::Context -> String
    @ssl : OpenSSL::SSL::Context::Server?

    property host_binding, ssl, port, env, public_folder, logging,
      always_rescue, serve_static, server, extra_options

    def initialize
      @host_binding = "0.0.0.0"
      @port = 3000
      @env = "development"
      @serve_static = true
      @public_folder = "./public"
      @logging = true
      @logger = nil
      @error_handler = nil
      @always_rescue = true
      @server = uninitialized HTTP::Server
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

    def handlers
      HANDLERS
    end

    def add_handler(handler : HTTP::Handler)
      HANDLERS << handler
    end

    def add_ws_handler(handler : HTTP::WebSocketHandler)
      HANDLERS << handler
    end

    def error_handlers
      ERROR_HANDLERS
    end

    def add_error_handler(status_code, &handler : HTTP::Server::Context -> _)
      ERROR_HANDLERS[status_code] = ->(context : HTTP::Server::Context) { handler.call(context).to_s }
    end

    def extra_options(&@extra_options : OptionParser ->)
    end

    def setup
      setup_init_handler
      setup_log_handler
      setup_error_handler
      setup_static_file_handler
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
      HANDLERS.insert(3, Kemal::StaticFileHandler.new(@public_folder)) if @serve_static
    end
  end

  def self.config
    yield Config::INSTANCE
  end

  def self.config
    Config::INSTANCE
  end
end
