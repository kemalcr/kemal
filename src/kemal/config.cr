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

    property public_folder = "./public"
    property logging = true
    property always_rescue = true
    property serve_static : Hash(String, Bool) | Bool = {"dir_listing" => false, "gzip" => true}
    property static_headers : (HTTP::Server::Response, String, File::Info -> Void)?
    property powered_by_header : Bool = true
    property app_name = "Kemal"

    @logger : Kemal::BaseLogHandler?

    def initialize(@app : Kemal::Application)
    end

    def logger : Kemal::BaseLogHandler
      @logger ||= if logging
                    Kemal::LogHandler.new
                  else
                    Kemal::NullLogHandler.new
                  end
    end

    def logger=(@logger : Kemal::BaseLogHandler)
    end

    def scheme
      ssl ? "https" : "http"
    end

    def clear
      @app.clear
    end

    def handlers
      @app.handlers
    end

    def handlers=(handlers : Array(HTTP::Handler))
      @app.handlers = handlers
    end

    def add_handler(handler : HTTP::Handler)
      @app.add_handler(handler)
    end

    def add_handler(handler : HTTP::Handler, position : Int32)
      @app.add_handler(handler, position)
    end

    def add_filter_handler(handler : HTTP::Handler)
      @app.add_filter_handler(handler)
    end

    def error_handlers
      @app.error_handlers
    end

    def setup
      @app.setup
    end
  end
end
