require "option_parser"

module Kemal
  # Handles all the initialization from the command line.
  class CLI
    def initialize
      @ssl_enabled = false
      @key_file = ""
      @cert_file = ""
      @config = Kemal.config
      read_env
      parse
      configure_ssl
    end

    def parse
      OptionParser.parse! do |opts|
        opts.on("-b HOST", "--bind HOST", "Host to bind (defaults to 0.0.0.0)") do |host_binding|
          @config.host_binding = host_binding
        end
        opts.on("-p PORT", "--port PORT", "Port to listen for connections (defaults to 3000)") do |opt_port|
          @config.port = opt_port.to_i
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

    def configure_ssl
      {% if !flag?(:without_openssl) %}
      if @ssl_enabled
        unless @key_file
          puts "SSL Key Not Found"
          exit
        end
        unless @cert_file
          puts "SSL Certificate Not Found"
          exit
        end
        ssl = Kemal::Middleware::SSL.new
        ssl.set_key_file @key_file.not_nil!
        ssl.set_cert_file @cert_file.not_nil!
        Kemal.config.ssl = ssl.context
      end
    {% end %}
    end

    def read_env
      @config.env = ENV["KEMAL_ENV"] if ENV.has_key?("KEMAL_ENV")
    end
  end
end
