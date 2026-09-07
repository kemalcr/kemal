require "http"
require "json"
require "log"
require "uri"
require "./kemal/*"
require "./kemal/ext/*"
require "./kemal/helpers/*"

module Kemal
  Log = ::Log.for(self)

  # How often the shutdown drain re-checks the in-flight request count.
  private DRAIN_POLL_INTERVAL = 10.milliseconds

  # Overload of `self.run` with the default startup logging.
  def self.run(port : Int32?, args = ARGV, trap_signal : Bool = true)
    run(port, args, trap_signal) { }
  end

  # Overload of `self.run` without port.
  def self.run(args = ARGV, trap_signal : Bool = true)
    run(nil, args: args, trap_signal: trap_signal)
  end

  # Overload of `self.run` to allow just a block.
  def self.run(args = ARGV, &block)
    run(nil, args: args, trap_signal: true, &block)
  end

  # The command to run a `Kemal` application.
  #
  # If *port* is not given Kemal will use `Kemal::Config#port`
  #
  # To use custom command line arguments, set args to nil
  #
  # Returns once the server has been stopped - by `Kemal.stop` or by a termination
  # signal - and the requests that were being served at that moment have finished,
  # or `Kemal::Config#shutdown_timeout` has elapsed, whichever comes first.
  def self.run(port : Int32? = nil, args = ARGV, trap_signal : Bool = true, &)
    Kemal::CLI.new args
    config = Kemal.config
    config.setup
    config.port = port if port

    # Test environment doesn't need to have signal trap and logging.
    if config.env != "test"
      setup_404
      setup_trap_signal if trap_signal
    end

    server = config.server ||= HTTP::Server.new(config.handlers)

    config.running = true

    yield config

    # Abort if block called `Kemal.stop`
    return if !config.running

    if config.env != "test"
      if !server.each_address { |_| break true }
        {% if flag?(:without_openssl) %}
          server.bind_tcp(config.host_binding, config.port)
        {% else %}
          if ssl = config.ssl
            server.bind_tls(config.host_binding, config.port, ssl)
          else
            server.bind_tcp(config.host_binding, config.port)
          end
        {% end %}
      end
    end

    display_startup_message(config, server)

    server.listen if config.env != "test"

    # `HTTP::Server#listen` returns as soon as the listeners are closed, while the
    # requests they accepted are still being served on their own fibers. Falling off
    # the end of the program here would cut those off mid-response, so stay until
    # they are done - or give up on them after `shutdown_timeout`.
    wait_for_in_flight_requests(config)
  end

  def self.display_startup_message(config, server)
    if config.env != "test"
      addresses = server.addresses.join ", " { |address| "#{config.scheme}://#{address}" }
      Log.info { "[#{config.env}] #{config.app_name} is ready to lead at #{addresses}" }
    else
      Log.info { "[#{config.env}] #{config.app_name} is running in test mode. Server not listening" }
    end
  end

  # Stops accepting connections. Requests already being served are left to finish;
  # `Kemal.run` waits for them before it returns (see `Kemal::Config#shutdown_timeout`).
  def self.stop
    raise "#{Kemal.config.app_name} is already stopped. Cannot stop an already stopped server." if !config.running
    if server = config.server
      # Flag first: a health check that reads `Kemal.config.running` can start
      # reporting the drain before the listener is gone.
      config.running = false
      server.close unless server.closed?
    else
      raise "Cannot stop #{Kemal.config.app_name}: server instance is not set. Please ensure Kemal.run has been called before calling Kemal.stop."
    end
  end

  # Blocks until no request is in flight, or *config*.shutdown_timeout has passed.
  private def self.wait_for_in_flight_requests(config)
    remaining = config.shutdown_timeout

    until (in_flight = InitHandler::INSTANCE.in_flight).zero?
      if remaining <= Time::Span.zero
        Log.warn { "#{in_flight} request(s) still in flight after #{config.shutdown_timeout}; shutting down anyway" }
        return
      end

      sleep DRAIN_POLL_INTERVAL
      remaining -= DRAIN_POLL_INTERVAL
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
    Process.on_terminate do
      if Kemal.config.running
        Log.info { "#{Kemal.config.app_name} is going to take a rest!" } if Kemal.config.shutdown_message
        # Only closes the listeners; `Kemal.run` is what waits for the requests still
        # being served, then returns. Nothing to `exit` here.
        Kemal.stop
      else
        # A second signal during the drain means "now": stop waiting for whatever is
        # still in flight.
        exit
      end
    end
  end
end
