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

def create_request_and_return_io(handler, request, app = Kemal.application)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  context.app = app
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
