require "option_parser"

module Kemal
  class CLI
    def initialize
      @ssl_enabled = false
      @key_file = nil
      @cert_file = nil
      @config = Kemal.config
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
        opts.on("-e ENV", "--environment ENV", "Environment [development, production] (defaults to development). Set `production` to boost performance") do |env|
          @config.env = env
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
      end
    end

    def configure_ssl
      if @ssl_enabled
        puts "SSL Key Not Found"; exit unless @key_file
        puts "SSL Certificate Not Found"; exit unless @cert_file
        ssl = Kemal::Middleware::SSL.new
        ssl.set_key_file @key_file.not_nil!.to_slice
        ssl.set_cert_file @cert_file.not_nil!.to_slice
        Kemal.config.ssl = ssl.context
      end
    end
  end
end
