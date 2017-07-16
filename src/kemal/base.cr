# Kemal Base
# The DSL currently consists of
# - get post put patch delete options
# - WebSocket(ws)
# - before_*
# - error
class Kemal::Base
  HTTP_METHODS   = %w(get post put patch delete options)
  FILTER_METHODS = %w(get post put patch delete options all)

  getter route_handler = Kemal::RouteHandler.new
  getter filter_handler = Kemal::FilterHandler.new
  getter websocket_handler = Kemal::WebSocketHandler.new

  getter handlers = [] of HTTP::Handler
  getter custom_handlers = [] of Tuple(Nil | Int32, HTTP::Handler)
  getter filter_handlers = [] of HTTP::Handler
  getter error_handlers = {} of Int32 => HTTP::Server::Context, Exception -> String
  @handler_position = 0

  getter config : Config

  property! logger : Kemal::BaseLogHandler
  property! server : HTTP::Server
  property? running = false

  def initialize(@config = Config.new)
    @logger = if @config.logging?
                Kemal::LogHandler.new
              else
                Kemal::NullLogHandler.new
              end
    add_filter_handler(filter_handler)
  end

  {% for method in HTTP_METHODS %}
    def {{method.id}}(path, &block : HTTP::Server::Context -> _)
      raise Kemal::Exceptions::InvalidPathStartException.new({{method}}, path) unless Kemal::Utils.path_starts_with_slash?(path)
      route_handler.add_route({{method}}.upcase, path, &block)
    end
  {% end %}

  def ws(path, &block : HTTP::WebSocket, HTTP::Server::Context -> Void)
    raise Kemal::Exceptions::InvalidPathStartException.new("ws", path) unless Kemal::Utils.path_starts_with_slash?(path)
    websocket_handler.add_route path, &block
  end

  def error(status_code, &block : HTTP::Server::Context, Exception -> _)
    add_error_handler status_code, &block
  end

  # All the helper methods available are:
  #  - before_all, before_get, before_post, before_put, before_patch, before_delete, before_options
  #  - after_all, after_get, after_post, after_put, after_patch, after_delete, after_options
  {% for type in ["before", "after"] %}
    {% for method in FILTER_METHODS %}
      def {{type.id}}_{{method.id}}(path = "*", &block : HTTP::Server::Context -> _)
        filter_handler.{{type.id}}({{method}}.upcase, path, &block)
      end
    {% end %}
  {% end %}

  def clear
    @router_included = false
    @handler_position = 0
    @default_handlers_setup = false

    handlers.clear
    custom_handlers.clear
    filter_handlers.clear
    error_handlers.clear

    route_handler.clear
    websocket_handler.clear
  end

  def handlers=(handlers : Array(HTTP::Handler))
    clear
    @handlers.replace(handlers)
  end

  def add_handler(handler : HTTP::Handler)
    @custom_handlers << {nil, handler}
  end

  def add_handler(handler : HTTP::Handler, position : Int32)
    @custom_handlers << {position, handler}
  end

  def add_filter_handler(handler : HTTP::Handler)
    @filter_handlers << handler
  end

  def add_error_handler(status_code, &handler : HTTP::Server::Context, Exception -> _)
    @error_handlers[status_code] = ->(context : HTTP::Server::Context, error : Exception) { handler.call(context, error).to_s }
  end

  def setup
    unless @default_handlers_setup && @router_included
      setup_init_handler
      setup_log_handler
      setup_error_handler
      setup_static_file_handler
      setup_custom_handlers
      setup_filter_handlers
      @default_handlers_setup = true
      @router_included = true
      handlers.insert(handlers.size, websocket_handler)
      handlers.insert(handlers.size, route_handler)
    end
  end

  private def setup_init_handler
    @handlers.insert(@handler_position, Kemal::InitHandler.new(self))
    @handler_position += 1
  end

  private def setup_log_handler
    @handlers.insert(@handler_position, logger)
    @handler_position += 1
  end

  private def setup_error_handler
    if @config.always_rescue?
      @error_handler ||= Kemal::ExceptionHandler.new
      @handlers.insert(@handler_position, @error_handler.not_nil!)
      @handler_position += 1
    end
  end

  private def setup_static_file_handler
    if @config.serve_static.is_a?(Hash)
      @handlers.insert(@handler_position, Kemal::StaticFileHandler.new(@config.public_folder))
      @handler_position += 1
    end
  end

  private def setup_custom_handlers
    @custom_handlers.each do |ch|
      position = ch[0]
      if !position
        @handlers.insert(@handler_position, ch[1])
        @handler_position += 1
      else
        @handlers.insert(position, ch[1])
        @handler_position += 1
      end
    end
  end

  private def setup_filter_handlers
    @filter_handlers.each do |h|
      @handlers.insert(@handler_position, h)
    end
  end

  # Overload of self.run with the default startup logging
  def run(port = nil)
    run port do
      log "[#{config.env}] Kemal is ready to lead at #{config.scheme}://#{config.host_binding}:#{config.port}"
    end
  end

  # Overload of self.run to allow just a block
  def run(&block)
    run nil, &block
  end

  # The command to run a `Kemal` application.
  # The port can be given to `#run` but is optional.
  # If not given Kemal will use `Kemal::Config#port`
  def run(port = nil, &block)
    @config.port = port if port

    setup

    @server = server = HTTP::Server.new(@config.host_binding, @config.port, @handlers)
    {% if !flag?(:without_openssl) %}
    server.tls = config.ssl
    {% end %}

    unless error_handlers.has_key?(404)
      error 404 do |env|
        render_404
      end
    end

    # Test environment doesn't need to have signal trap, built-in images, and logging.
    unless config.env == "test"
      Signal::INT.trap do
        log "Kemal is going to take a rest!" if config.shutdown_message?
        Kemal.stop if running?
        exit
      end

      # This route serves the built-in images for not_found and exceptions.
      get "/__kemal__/:image" do |env|
        image = env.params.url["image"]
        file_path = File.expand_path("lib/kemal/images/#{image}", Dir.current)
        if File.exists? file_path
          send_file env, file_path
        else
          halt env, 404
        end
      end
    end

    @running = true

    yield self

    server.listen if @config.env != "test"
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
end
