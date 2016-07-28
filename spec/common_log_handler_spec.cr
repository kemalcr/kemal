require "./spec_helper"

describe "Kemal::CommonLogHandler" do
  it "logs to the given IO" do
    config = Kemal.config
    io = MemoryIO.new
    logger = Kemal::CommonLogHandler.new io
    logger.write "Something"
    io.to_s.should eq "Something"
  end

  it "creates log message for each request" do
    request = HTTP::Request.new("GET", "/")
    io = MemoryIO.new
    context_io = MemoryIO.new
    response = HTTP::Server::Response.new(context_io)
    context = HTTP::Server::Context.new(request, response)
    logger = Kemal::CommonLogHandler.new io
    logger.call(context)
    io.to_s.should_not be nil
  end
end
