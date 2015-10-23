require "option_parser"
require "./Kemal/*"

at_exit do
  OptionParser.parse! do |opts|
    opts.on("-p ", "--port ", "port") do |opt_port|
      Kemal.config.port = opt_port.to_i
    end
  end

  config = Kemal.config
  handlers = [] of HTTP::Handler
  handlers << HTTP::LogHandler.new
  handlers << Kemal::Handler::INSTANCE
  handlers << HTTP::StaticFileHandler.new("./public")
  server = HTTP::Server.new(config.port, handlers)

  server.ssl = config.ssl

  puts "Listening on #{config.scheme}://0.0.0.0:#{config.port}"
  server.listen
end
