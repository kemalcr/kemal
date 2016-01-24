require "./spec_helper"

describe "Logger" do
  it "creates a handler" do
    logger = Kemal::Logger.new
    logger.handler.should_not be nil
  end

  it "creates a STDOUT handler by default" do
    config = Kemal.config
    logger = Kemal::Logger.new
    logger.handler.should be_a IO
  end

  it "creates a file handler in production" do
    config = Kemal.config
    config.env = "production"
    logger = Kemal::Logger.new
    logger.handler.should be_a File
  end

  it "writes to a file in production" do
    config = Kemal.config
    config.env = "production"
    logger = Kemal::Logger.new
    request = HTTP::Request.new("GET", "/?message=world&time=now")
    io = MemoryIO.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    logger.call(context)
    response.close
    str = File.read("kemal.log")
    File.delete("kemal.log")
    str.includes?("GET /?message=world&time=now").should eq true
  end
end
