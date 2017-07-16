require "./spec_helper"

describe "Kemal::InitHandler" do
  it "initializes context with Content-Type: text/html" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    init_handler = Kemal::InitHandler.new(Kemal::Base.new)
    init_handler.next = ->(context : HTTP::Server::Context) {}
    init_handler.call(context)
    context.response.headers["Content-Type"].should eq "text/html"
  end

  it "initializes context with X-Powered-By: Kemal" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    init_handler = Kemal::InitHandler.new(Kemal::Base.new)
    init_handler.call(context)
    context.response.headers["X-Powered-By"].should eq "Kemal"
  end
end
