require "spec"
require "../src/*"

include Kemal

class CustomTestHandler < HTTP::Handler
  def call(request)
    call_next request
  end
end

class CustomLogHandler < Kemal::BaseLogHandler; end

def create_request_and_return_io(handler, request)
  io = MemoryIO.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler.call(context)
  response.close
  io.rewind
  io
end

def create_ws_request_and_return_io(handler, request)
  io = MemoryIO.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  begin
    handler.call context
  rescue IO::Error
    # Raises because the MemoryIO is empty
  end
  response.close
  io
end

def call_request_on_app(request)
  io = MemoryIO.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  Kemal::RouteHandler::INSTANCE.call(context)
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, decompress: false)
end

Spec.before_each do
  config = Kemal.config
  config.env = "development"
  config.setup
  config.add_handler Kemal::RouteHandler::INSTANCE
end

Spec.after_each do
  Kemal.config.handlers.clear
  Kemal::RouteHandler::INSTANCE.tree = Radix::Tree.new
end
