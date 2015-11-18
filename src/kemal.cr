require "option_parser"
require "./kemal/*"

at_exit do
  OptionParser.parse! do |opts|
    opts.on("-p ", "--port ", "port") do |opt_port|
      Kemal.config.port = opt_port.to_i
    end
    opts.on("-e ", "--environment ", "environment") do |env|
      Kemal.config.env = env
    end
  end

  config = Kemal.config
  config.add_handler Kemal::Logger.new
  config.add_handler Kemal::Handler::INSTANCE
  config.add_handler HTTP::StaticFileHandler.new("./public")

  server = HTTP::Server.new(config.port, config.handlers)
  server.ssl = config.ssl
  server.listen
end
