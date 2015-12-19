require "yaml"

module Kemal
  class Config
    INSTANCE = Config.new
    HANDLERS = [] of HTTP::Handler
    property ssl, port, env, public_folder

    def initialize
      @port = 3000
      @env = "development" unless @env
      @public_folder = "./public"
      read_file
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

    # Reads configuration from config.yml. Currently it only supports the public_folder
    # option.
    # config.yml
    # public_folder = "root/to/folder"
    def read_file
      path = File.expand_path("config.yml", Dir.working_directory)
      if File.exists?(path)
        data = YAML.load(File.read(path)) as Hash
        public_folder = File.expand_path("./#{data["public_folder"]}", Dir.working_directory)
        @public_folder = public_folder
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
