module Kemal
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}

  # Stores all the configuration options for a Kemal application.
  # It's a singleton and you can access it like.
  #
  # ```
  # Kemal.config
  # ```
  class Config
    INSTANCE           = Config.new
    HANDLERS           = [] of HTTP::Handler
    CUSTOM_HANDLERS    = [] of Tuple(Int32?, HTTP::Handler)
    FILTER_HANDLERS    = [] of HTTP::Handler
    ERROR_HANDLERS     = {} of Int32 => HTTP::Server::Context, Exception -> String
    EXCEPTION_HANDLERS = {} of Exception.class => HTTP::Server::Context, Exception -> String

    {% if flag?(:without_openssl) %}
      @ssl : Bool?
    {% else %}
      @ssl : OpenSSL::SSL::Context::Server?
    {% end %}

    property app_name, host_binding, ssl, port, env, public_folder, logging, running
    property always_rescue, server : HTTP::Server?, extra_options, shutdown_message, shutdown_timeout
    property serve_static : (Bool | Hash(String, Bool))
    property static_headers : (HTTP::Server::Context, String, File::Info ->)?
    property? powered_by_header : Bool = false
    property max_route_cache_size : Int32
    property max_request_body_size : Int32
    property max_multipart_form_field_size : Int32
    # Maximum number of byte ranges accepted in a single `Range` request header.
    #
    # A `Range` header listing more parts than this is ignored and the full representation
    # is served with `200` instead. Since `send_file` also refuses range sets asking for
    # more bytes in total than the file holds, a multi-range response stays within the
    # file's own size plus roughly 150 bytes of multipart framing per part. Raising this
    # therefore raises the framing a single request can ask for; `0` ignores `Range`
    # headers entirely and advertises `Accept-Ranges: none`.
    #
    # Without a bound, a header such as `bytes=0-,0-,0-,...` makes the server re-read the
    # whole file once per range. RFC 9110 §14.2 explicitly allows rejecting such range
    # sets, as they indicate "either a broken client or a deliberate denial-of-service
    # attack".
    property max_ranges : Int32
    # WebSocket Origin policy for upgrade requests.
    #
    # - Empty (default): same-origin — `Origin` must match the request `Host` (scheme is
    #   taken from `Origin`, so TLS termination in front of Kemal still works). Missing or
    #   empty `Origin` is rejected with 403.
    # - Non-empty allowlist: `Origin` must match one of the entries after normalization
    #   (scheme/host/port only). Missing `Origin` is rejected.
    # - Include `"*"` to allow any origin, including requests without `Origin` (previous
    #   allow-all behavior).
    # - Use `"null"` to allow the browser's opaque `"null"` origin.
    #
    # Entries use the serialized origin form, e.g. `"https://example.com"` or
    # `"http://localhost:3000"`.
    property websocket_allowed_origins : Array(String)

    def initialize
      @app_name = "Kemal"
      @host_binding = "0.0.0.0"
      @port = 3000
      @env = ENV["KEMAL_ENV"]? || "development"
      @serve_static = {"dir_listing" => false, "gzip" => true, "dir_index" => false}
      @public_folder = "./public"
      @logging = true
      @logger = nil
      @error_handler = nil
      @always_rescue = true
      @router_included = false
      @default_handlers_setup = false
      @running = false
      @shutdown_message = true
      @shutdown_timeout = 0.seconds
      @handler_position = 0
      @max_route_cache_size = 1024
      @max_request_body_size = 8 * 1024 * 1024         # 8MB
      @max_multipart_form_field_size = 8 * 1024 * 1024 # 8MB
      @max_ranges = 16
      @websocket_allowed_origins = [] of String
    end

    @[Deprecated("Use standard library Log")]
    def logger
      @logger || NullLogHandler.new
    end

    # :nodoc:
    def logger?
      @logger
    end

    @[Deprecated("Use standard library Log")]
    def logger=(logger : Kemal::BaseLogHandler)
      @logger = logger
    end

    def scheme
      ssl ? "https" : "http"
    end

    def clear
      @powered_by_header = false
      @router_included = false
      @handler_position = 0
      @default_handlers_setup = false
      @max_route_cache_size = 1024
      @max_request_body_size = 8 * 1024 * 1024
      @max_multipart_form_field_size = 8 * 1024 * 1024
      @max_ranges = 16
      @websocket_allowed_origins = [] of String
      HANDLERS.clear
      CUSTOM_HANDLERS.clear
      FILTER_HANDLERS.clear
      ERROR_HANDLERS.clear
      EXCEPTION_HANDLERS.clear
    end

    def handlers
      HANDLERS
    end

    def handlers=(handlers : Array(HTTP::Handler))
      clear
      HANDLERS.replace(handlers)
    end

    def add_handler(handler : HTTP::Handler)
      CUSTOM_HANDLERS << {nil, handler}
    end

    def add_handler(handler : HTTP::Handler, position : Int32)
      CUSTOM_HANDLERS << {position, handler}
    end

    def add_filter_handler(handler : HTTP::Handler)
      FILTER_HANDLERS << handler
    end

    # Returns the defined error handlers for HTTP status codes
    def error_handlers
      ERROR_HANDLERS
    end

    # Adds an error handler for the given HTTP status code
    def add_error_handler(status_code : Int32, &handler : HTTP::Server::Context, Exception -> _)
      ERROR_HANDLERS[status_code] = ->(context : HTTP::Server::Context, error : Exception) { handler.call(context, error).to_s }
    end

    # Returns the defined error handlers for exceptions
    def exception_handlers
      EXCEPTION_HANDLERS
    end

    # Adds an error handler for the given exception
    def add_exception_handler(exception : Exception.class, &handler : HTTP::Server::Context, Exception -> _)
      EXCEPTION_HANDLERS[exception] = ->(context : HTTP::Server::Context, error : Exception) { handler.call(context, error).to_s }
    end

    def extra_options(&@extra_options : OptionParser ->)
    end

    def setup
      unless @default_handlers_setup && @router_included
        setup_init_handler
        setup_log_handler
        setup_head_request_handler
        setup_error_handler
        setup_static_file_handler
        setup_custom_handlers
        setup_filter_handlers
        @default_handlers_setup = true
        @router_included = true
        HANDLERS.insert(HANDLERS.size, Kemal::WebSocketHandler::INSTANCE)
        HANDLERS.insert(HANDLERS.size, Kemal::RouteHandler::INSTANCE)
      end
    end

    private def setup_init_handler
      HANDLERS.insert(@handler_position, Kemal::InitHandler::INSTANCE)
      @handler_position += 1
    end

    private def setup_log_handler
      return unless @logging

      log_handler = @logger || Kemal::RequestLogHandler.new

      HANDLERS.insert(@handler_position, log_handler)
      @handler_position += 1
    end

    private def setup_head_request_handler
      HANDLERS.insert(@handler_position, Kemal::HeadRequestHandler::INSTANCE)
      @handler_position += 1
    end

    private def setup_error_handler
      if @always_rescue
        handler = @error_handler ||= Kemal::ExceptionHandler.new
        HANDLERS.insert(@handler_position, handler)
        @handler_position += 1
      end
    end

    private def setup_static_file_handler
      if @serve_static.is_a?(Hash)
        HANDLERS.insert(@handler_position, Kemal::StaticFileHandler.new(@public_folder))
        @handler_position += 1
      end
    end

    private def setup_custom_handlers
      CUSTOM_HANDLERS.each do |ch0, ch1|
        position = ch0
        HANDLERS.insert (position || @handler_position), ch1
        @handler_position += 1
      end
    end

    private def setup_filter_handlers
      FILTER_HANDLERS.each do |handler|
        HANDLERS.insert(@handler_position, handler)
      end
    end
  end

  def self.config(&)
    yield Config::INSTANCE
  end

  def self.config
    Config::INSTANCE
  end
end
