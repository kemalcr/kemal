require "spec"
require "../src/*"

include Kemal

class CustomLogHandler < Kemal::BaseLogHandler
  def call(context)
    call_next(context)
  end

  def write(message)
  end
end

# Used by `config_spec` and `handler_spec` alike, so it lives here and each
# spec file compiles on its own.
class CustomTestHandler < Kemal::Handler
  def call(env)
    env.response << "Kemal"
    call_next env
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

class CustomExceptionType < Exception
end

class ChildCustomExceptionType < CustomExceptionType
end

add_context_storage_type(TestContextStorageType)
add_context_storage_type(AnotherContextStorageType)

def create_request_and_return_io_and_context(handler, request)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler.call(context)
  response.close
  io.rewind
  {io, context}
end

def create_ws_request_and_return_io_and_context(handler, request)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  begin
    handler.call context
  rescue IO::Error
    # Raises because the IO::Memory is empty
  end
  {% if compare_versions(Crystal::VERSION, "0.35.0-0") >= 0 %}
    response.upgrade_handler.try &.call(io)
  {% end %}
  io.rewind
  {io, context}
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
  Kemal.config.setup
  main_handler = Kemal.config.handlers.first
  current_handler = main_handler
  Kemal.config.handlers.each do |handler|
    current_handler.next = handler
    current_handler = handler
  end
  main_handler
end

# Crystal 1.21 runs on execution contexts by default, but the default context
# starts with a parallelism of one. `KEMAL_SPEC_WORKERS=N` widens it so the
# suite exercises the request path from several threads at once - the setting
# CI uses to catch shared state the single-threaded run cannot see.
{% if compare_versions(Crystal::VERSION, "1.21.0") >= 0 %}
  if workers = ENV["KEMAL_SPEC_WORKERS"]?.try(&.to_i?)
    Fiber::ExecutionContext.default.resize(workers)
  end
{% end %}

Spec.before_each do
  config = Kemal.config
  config.env = "development"
  config.logging = false
end

Spec.after_each do
  Kemal.config.clear
  Kemal::FilterHandler::INSTANCE.tree = Radix::Tree(Array(Kemal::FilterHandler::FilterBlock)).new
  Kemal::RouteHandler::INSTANCE.routes = Radix::Tree(Route).new
  Kemal::RouteHandler::INSTANCE.cached_routes = Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(Kemal.config.max_route_cache_size)
  Kemal::WebSocketHandler::INSTANCE.routes = Radix::Tree(WebSocket).new
end
