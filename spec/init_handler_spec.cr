require "./spec_helper"

describe "Kemal::InitHandler" do
  it "initializes context with Content-Type: text/html" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::InitHandler::INSTANCE.next = ->(_context : HTTP::Server::Context) { }
    Kemal::InitHandler::INSTANCE.call(context)
    context.response.headers["Content-Type"].should eq "text/html"
  end

  it "initializes context with Date header" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::InitHandler::INSTANCE.next = ->(_context : HTTP::Server::Context) { }
    Kemal::InitHandler::INSTANCE.call(context)
    date = context.response.headers["Date"]?.should_not be_nil
    date = HTTP.parse_time(date).should_not be_nil
    date.should be_close(Time.utc, 1.second)
  end

  it "initializes context with X-Powered-By: Kemal" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::InitHandler::INSTANCE.call(context)
    context.response.headers["X-Powered-By"].should eq "Kemal"
  end

  it "does not initialize context with X-Powered-By: Kemal if disabled" do
    Kemal.config.powered_by_header = false
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::InitHandler::INSTANCE.call(context)
    context.response.headers["X-Powered-By"]?.should be_nil
  end

  it "wraps request body in BoundedTotalBodyIO for POST" do
    request = HTTP::Request.new("POST", "/", body: IO::Memory.new("x"))
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::InitHandler::INSTANCE.next = ->(_context : HTTP::Server::Context) { }
    Kemal::InitHandler::INSTANCE.call(context)
    inner = context.request.body
    inner.should be_a(Kemal::BoundedTotalBodyIO)
    inner.as(Kemal::BoundedTotalBodyIO).read_byte.should eq('x'.ord.to_u8)
  end

  it "wraps request body for HEAD when a body IO is present" do
    request = HTTP::Request.new("HEAD", "/", body: IO::Memory.new("x"))
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::InitHandler::INSTANCE.next = ->(_context : HTTP::Server::Context) { }
    Kemal::InitHandler::INSTANCE.call(context)
    context.request.body.should be_a(Kemal::BoundedTotalBodyIO)
  end
end
