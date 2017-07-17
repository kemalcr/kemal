require "spec"
require "../src/kemal"

def call_request_on_app(app, request)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  main_handler = build_main_handler(app)
  main_handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, decompress: false)
end

def build_main_handler(app)
  app.setup
  main_handler = app.handlers.first
  current_handler = main_handler
  app.handlers.each_with_index do |handler, index|
    current_handler.next = handler
    current_handler = handler
  end
  main_handler
end
