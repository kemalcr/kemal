require "./helpers/*"
require "./base/*"

# Kemal Base
# The DSL currently consists of
# - get post put patch delete options
# - WebSocket(ws)
# - before_*
# - error
class Kemal::Base
  include FileHelpers
  include Templates
  include Macros
  include Base::DSL
  include Base::Builder

  # :nodoc:
  # TODO: These ivars are initialized in the constructor, but their values depend on `self`.
  getter! route_handler : RouteHandler?
  # :nodoc:
  getter! filter_handler : FilterHandler?
  # :nodoc:
  getter! websocket_handler : WebSocketHandler?

  getter handlers = [] of HTTP::Handler
  getter error_handlers = {} of Int32 => HTTP::Server::Context, Exception -> String

  getter config : Config

  property! logger : BaseLogHandler
  property! server : HTTP::Server
  property? running = false

  def initialize(@config = Config.base)
    @filter_handler = FilterHandler.new(self)
    @route_handler = RouteHandler.new(self)
    @websocket_handler = WebSocketHandler.new(self)

    initialize_defaults
  end

  # Overload of self.run with the default startup logging
  def run(port : Int32? = nil)
    run(port) { }
  end

  # The command to run a `Kemal` application.
  # The port can be given to `#run` but is optional.
  # If not given Kemal will use `Kemal::Config#port`
  def run(port : Int32? = nil)
    setup

    prepare_for_server_start

    start_server(port) do
      yield self
    end
  end

  def self.run(port : Int32? = nil)
    new.tap do |app|
      Kemal::CLI.new(app.config)

      app.run(port) do
        yield app
      end
    end
  end

  def self.run(port : Int32? = nil)
    run(port) { }
  end

  # DEPRECATED: This method should be replaced with `#running?`
  def running
    running?
  end

  private def prepare_for_server_start
  end

  private def start_server(port)
    @server = server = HTTP::Server.new(@handlers)

    {% if flag?(:without_openssl) %}
      server.bind_tcp(@config.host_binding, port || @config.port)
    {% else %}
      if ssl = config.ssl
        server.bind_tls(@config.host_binding, port || @config.port, ssl)
      else
        server.bind_tcp(@config.host_binding, port || @config.port)
      end
    {% end %}

    @running = true

    yield

    server.listen unless @config.env == "test"
  end

  def stop
    if @running
      if server = @server
        server.close
        @running = false
      else
        raise "server is not set. Please use run to set the server."
      end
    else
      raise "Kemal is already stopped."
    end
  end

  def log(message)
    logger.write "#{message}\n"
  end
end

require "./main"
