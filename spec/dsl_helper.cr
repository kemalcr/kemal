require "./spec_helper"
require "../src/kemal/dsl"

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
  context.app = Kemal.application
  handler.call(context)
  response.close
  io.rewind
  io
end

def call_request_on_app(request)
  call_request_on_app(Kemal.application, request)
end

def build_main_handler
  build_main_handler(Kemal.application)
end

Spec.before_each do
  config = Kemal.config
  config.env = "development"
end

Spec.after_each do
  Kemal.application.clear
end
