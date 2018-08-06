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
    self.run(port) { }
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

    # Test environment doesn't need to have signal trap and logging.
    if config.env != "test"
      setup_404
      setup_trap_signal
    end

    server = config.server ||= HTTP::Server.new(config.handlers)

    config.running = true

    yield config

    # Abort if block called `Kemal.stop`
    return unless config.running

    unless server.each_address { |_| break true }
      {% if flag?(:without_openssl) %}
        server.bind_tcp(config.host_binding, config.port)
      {% else %}
        if ssl = config.ssl
          server.bind_ssl(config.host_binding, config.port, ssl)
        else
          server.bind_tcp(config.host_binding, config.port)
        end
      {% end %}
    end

    display_startup_message(config, server)

    server.listen unless config.env == "test"
  end

  def self.display_startup_message(config, server)
    addresses = server.addresses.map { |address| "#{config.scheme}://#{address}" }.join ", "
    log "[#{config.env}] Kemal is ready to lead at #{addresses}"
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

  private def self.setup_404
    unless Kemal.config.error_handlers.has_key?(404)
      error 404 do
        render_404
      end
    end
  end

  private def self.setup_trap_signal
    Signal::INT.trap do
      log "Kemal is going to take a rest!" if Kemal.config.shutdown_message
      Kemal.stop
      exit
    end
  end
end
