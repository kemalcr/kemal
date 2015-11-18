module Kemal
  class Config
    INSTANCE = Config.new
    HANDLERS = [] of HTTP::Handler
    property ssl
    property port
    property env

    def initialize
      @port = 3000
      @env = "development" unless @env
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
  end

  def self.config
    yield Config::INSTANCE
  end

  def self.config
    Config::INSTANCE
  end
end
