require "option_parser"
require "./frank/*"

$frank_handler = Frank::Handler.new
port = 3000

OptionParser.parse! do |opts|
  opts.on("-p ", "--port ", "port") do |opt_port|
    port = opt_port.to_i
  end
end

at_exit do
  handlers = [] of HTTP::Handler
  handlers << HTTP::LogHandler.new
  handlers << HTTP::StaticFileHandler.new("./public")
  handlers << $frank_handler
  server = HTTP::Server.new(port, handlers)

  puts "Listening on http://0.0.0.0:#{port}"
  server.listen
end
