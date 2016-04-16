module Kemal
  class Config
    INSTANCE = Config.new
    HANDLERS = [] of HTTP::Handler
    @ssl : OpenSSL::SSL::Context?
    @server : HTTP::Server?

    property host_binding, ssl, port, env, public_folder, logging,
      always_rescue, serve_static, server

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
      @run = false
      @ssl = nil
      @server = nil
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

    def setup
      setup_logging
      setup_error_handler
      setup_public_folder
    end

    def setup_logging
      @logger ||= if @logging
                    Kemal::CommonLogHandler.new(@env)
                  else
                    Kemal::NullLogHandler.new(@env)
                  end
      HANDLERS.insert(0, @logger.not_nil!)
    end

    private def setup_error_handler
      if @always_rescue
        @error_handler ||= Kemal::CommonExceptionHandler.new
        HANDLERS.insert(1, @error_handler.not_nil!)
      end
    end

    private def setup_public_folder
      HANDLERS.insert(2, Kemal::StaticFileHandler.new(@public_folder)) if @serve_static
    end
  end

  def self.config
    yield Config::INSTANCE
  end

  def self.config
    Config::INSTANCE
  end
end
