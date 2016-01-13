require "option_parser"

module Kemal
  class CLI
    def initialize
      ssl = nil
      OptionParser.parse! do |opts|
        opts.on("-b HOST", "--bind HOST", "HTTP host to bind (defaults to 0.0.0.0)") do |host_binding|
          Kemal.config.host_binding = host_binding
        end
        opts.on("-p PORT", "--port PORT", "HTTP port to listen connections (defaults to 3000)") do |opt_port|
          Kemal.config.port = opt_port.to_i
        end
        opts.on("-e ENV", "--environment ENV", "Running environment [development, production] (defaults to development). Set `production` to boost performance") do |env|
          Kemal.config.env = env
        end
        opts.on("-s", "--ssl", "Enables SSL") do
          ssl = Kemal::Middleware::SSL.new
        end
        opts.on("--ssl-key-file FILE", "SSL key file") do |key_file|
          ssl.not_nil!.set_key_file key_file
        end
        opts.on("--ssl-cert-file FILE", "SSL certificate file") do |cert_file|
          ssl.not_nil!.set_cert_file cert_file
        end
        opts.on("-h", "--help", "Shows this help") do
          puts opts
          exit 0
        end
      end

      Kemal.config.ssl = ssl.not_nil!.context if ssl
    end
  end
end
