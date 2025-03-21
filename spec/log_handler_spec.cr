require "./spec_helper"

describe "Kemal::LogHandler" do
  it "creates log message for each request" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    context_io = IO::Memory.new
    response = HTTP::Server::Response.new(context_io)
    context = HTTP::Server::Context.new(request, response)
    logger = Kemal::LogHandler.new io
    logger.call(context)
    io.to_s.should_not be nil
  end
end
