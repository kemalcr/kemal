require "option_parser"
require "./frank/*"

at_exit do
  OptionParser.parse! do |opts|
    opts.on("-p ", "--port ", "port") do |opt_port|
      Frank.config.port = opt_port.to_i
    end
  end

  config = Frank.config
  handlers = [] of HTTP::Handler
  handlers << HTTP::LogHandler.new
  handlers << HTTP::StaticFileHandler.new("./public")
  handlers << Frank::Handler::INSTANCE
  server = HTTP::Server.new(config.port, handlers)

  server.ssl = config.ssl

  puts "Listening on #{config.scheme}://0.0.0.0:#{config.port}"
  server.listen
end
