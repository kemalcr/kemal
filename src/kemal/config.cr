module Kemal
  class Config
    INSTANCE = Config.new
    HANDLERS = [] of HTTP::Handler
    property host_binding, ssl, port, env, public_folder, logging, always_rescue, error_handler

    def initialize
      @host_binding = "0.0.0.0" unless @host_binding
      @port = 3000
      @env = "development" unless @env
      @public_folder = "./public"
      @logging = true
      @logger = nil
      @always_rescue = true
      @error_handler = nil
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

    def setup_logging
      if @logging
        @logger ||= Kemal::CommonLogHandler.new(@env)
        HANDLERS << @logger.not_nil!
      else
        @logger = Kemal::NullLogHandler.new(@env)
        HANDLERS << @logger.not_nil!
      end
    end

    def setup_error_handler
      if @always_rescue
        @error_handler ||= Kemal::CommonErrorHandler::INSTANCE
        HANDLERS << @error_handler.not_nil!
      end
    end
  end

  def self.config
    yield Config::INSTANCE
  end

  def self.config
    Config::INSTANCE
  end
end
