require "http"
require "json"
require "uri"
require "tempfile"
require "./application"
require "./base_log_handler"
require "./cli"
require "./exception_handler"
require "./log_handler"
require "./config"
require "./exceptions"
require "./file_upload"
require "./filter_handler"
require "./handler"
require "./init_handler"
require "./null_log_handler"
require "./param_parser"
require "./response"
require "./route"
require "./route_handler"
require "./ssl"
require "./static_file_handler"
require "./websocket"
require "./websocket_handler"
require "./ext/*"
require "./helpers/*"

module Kemal
  def self.application
    @@application ||= Kemal::Application.new
  end

  def self.config
    application.config
  end

  # Overload of `self.run` with the default startup logging.
  def self.run(port : Int32? = nil)
    CLI.new(config)

    application.run(port)
  end

  # The command to run a `Kemal` application.
  # The port can be given to `#run` but is optional.
  # If not given Kemal will use `Kemal::Config#port`
  def self.run(port : Int32? = nil)
    CLI.new(config)

    application.run(port) do |application|
      yield application
    end
  end

  def self.stop
    application.stop
  end
end
