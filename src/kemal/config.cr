require "yaml"

module Kemal
  class Config
    INSTANCE = Config.new
    HANDLERS = [] of HTTP::Handler
    property host_binding, ssl, port, env, public_folder, logging

    def initialize
      @host_binding = "0.0.0.0" unless @host_binding
      @port = 3000
      @env = "development" unless @env
      @public_folder = "./public"
      @logging = true
    end

    def scheme
      ssl ? "https" : "http"
    end

    def handlers
      HANDLERS
    end

    def logger
      @logger
    end

    def logger=(logger)
      HANDLERS << logger
      @logger = logger
    end

    def add_handler(handler : HTTP::Handler)
      HANDLERS << handler
    end

    def add_ws_handler(handler : HTTP::WebSocketHandler)
      HANDLERS << handler
    end
  end

  def self.config
    yield Config::INSTANCE
  end

  def self.config
    Config::INSTANCE
  end
end
