require "spec"
require "../src/*"

include Kemal

class CustomLogHandler < Kemal::BaseLogHandler
  def call(env)
    call_next env
  end

  def write(message)
  end
end

class TestContextStorageType
  property id
  @id = 1

  def to_s
    @id
  end
end

class AnotherContextStorageType
  property name
  @name = "kemal-context"
end

add_context_storage_type(TestContextStorageType)
add_context_storage_type(AnotherContextStorageType)

def create_request_and_return_io(handler, request)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler.call(context)
  response.close
  io.rewind
  io
end

def create_ws_request_and_return_io(handler, request)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  begin
    handler.call context
  rescue IO::Error
    # Raises because the IO::Memory is empty
  end
  response.close
  io
end

def call_request_on_app(request)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  main_handler = build_main_handler
  main_handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, decompress: false)
end

def build_main_handler
  main_handler = Kemal.config.handlers.first
  current_handler = main_handler
  Kemal.config.handlers.each_with_index do |handler, index|
    current_handler.next = handler
    current_handler = handler
  end
  main_handler
end

Spec.before_each do
  config = Kemal.config
  config.env = "development"
  config.setup
end

Spec.after_each do
  Kemal.config.clear
  Kemal::RouteHandler::INSTANCE.tree = Radix::Tree(Route).new
end
