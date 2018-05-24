require "http"
require "json"
require "uri"
require "tempfile"
require "./kemal/*"
require "./kemal/ext/*"
require "./kemal/helpers/*"

module Kemal
  # Overload of `self.run` with the default startup logging.
  def self.run(port : Int32?)
    self.run port do
      log "[#{config.env}] Kemal is ready to lead at #{config.scheme}://#{config.host_binding}:#{config.port}"
    end
  end

  # Overload of `self.run` without port.
  def self.run
    self.run(nil)
  end

  # Overload of `self.run` to allow just a block.
  def self.run(&block)
    self.run nil, &block
  end

  # The command to run a `Kemal` application.
  #
  # If *port* is not given Kemal will use `Kemal::Config#port`
  def self.run(port : Int32? = nil, &block)
    Kemal::CLI.new
    config = Kemal.config
    config.setup
    config.port = port if port

    unless Kemal.config.error_handlers.has_key?(404)
      error 404 do
        render_404
      end
    end

    # Test environment doesn't need to have signal trap, built-in images, and logging.
    unless config.env == "test"
      Signal::INT.trap do
        log "Kemal is going to take a rest!" if config.shutdown_message
        Kemal.stop
        exit
      end

      # This route serves the built-in images for not_found and exceptions.
      get "/__kemal__/404.png" do |env|
        file_path = File.expand_path("lib/kemal/images/404.png", Dir.current)

        if File.exists? file_path
          send_file env, file_path
        else
          halt env, 404
        end
      end
    end

    server = config.server ||= HTTP::Server.new(config.handlers)

    {% if !flag?(:without_openssl) %}
      config.server.not_nil!.tls = config.ssl
    {% end %}

    config.running = true

    yield config
    server.listen(config.host_binding, config.port) if config.env != "test"
  end

  def self.stop
    if config.running
      if server = config.server
        server.close unless server.closed?
        config.running = false
      else
        raise "Kemal.config.server is not set. Please use Kemal.run to set the server."
      end
    else
      raise "Kemal is already stopped."
    end
  end
end
