require "option_parser"

module Kemal
  # Handles all the initialization from the command line.
  class CLI
    # Ports `HTTP::Server#bind_tcp` accepts; 0 asks the operating system for a free port.
    private VALID_PORTS = 0..65535

    def initialize(args)
      @ssl_enabled = false
      @key_file = ""
      @cert_file = ""
      @config = Kemal.config
      if args
        parse args
      end
      configure_ssl
    end

    private def parse(args : Array(String))
      OptionParser.parse args do |opts|
        # Registered first so an application's `extra_options` can replace them.
        opts.invalid_option do |flag|
          abort "Invalid option: #{flag}\n\n#{opts}"
        end
        opts.missing_option do |flag|
          abort "Missing argument for option: #{flag}\n\n#{opts}"
        end
        opts.on("-b HOST", "--bind HOST", "Host to bind (defaults to #{@config.host_binding})") do |host_binding|
          @config.host_binding = host_binding
        end
        opts.on("-p PORT", "--port PORT", "Port to listen for connections (defaults to #{@config.port})") do |opt_port|
          @config.port = parse_port(opt_port)
        end
        opts.on("-s", "--ssl", "Enables SSL") do
          @ssl_enabled = true
        end
        opts.on("--ssl-key-file FILE", "SSL key file") do |key_file|
          @key_file = key_file
        end
        opts.on("--ssl-cert-file FILE", "SSL certificate file") do |cert_file|
          @cert_file = cert_file
        end
        opts.on("-h", "--help", "Shows this help") do
          puts opts
          exit 0
        end
        @config.extra_options.try &.call(opts)
      end
    end

    # `HTTP::Server#bind_tcp` reports a port outside `VALID_PORTS` as a hostname
    # lookup failure, so the value is checked here while it can still be named.
    # Surrounding whitespace is refused rather than trimmed: ` 8080` reaching the
    # flag means the value arrived from somewhere the operator wants to know about.
    private def parse_port(value : String) : Int32
      port = value.to_i?(whitespace: false)
      return port if port && VALID_PORTS.includes?(port)
      abort "Invalid port #{value.inspect}: must be an integer between #{VALID_PORTS.begin} and #{VALID_PORTS.end}."
    end

    private def configure_ssl
      {% if !flag?(:without_openssl) %}
        if @ssl_enabled
          abort "SSL configuration error: SSL key file not specified. Use --ssl-key-file FILE to specify the key file." if @key_file.empty?
          abort "SSL configuration error: SSL certificate file not specified. Use --ssl-cert-file FILE to specify the certificate file." if @cert_file.empty?
          ssl = Kemal::SSL.new
          ssl.key_file = @key_file
          ssl.cert_file = @cert_file
          Kemal.config.ssl = ssl.context
        end
      {% end %}
    end
  end
end
