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

  #TODO: Check https://github.com/manastech/crystal/issues/1899
  it "writes to a file in production" do
    config = Kemal.config
    config.env = "production"
    logger = Kemal::Logger.new
    request = HTTP::Request.new("GET", "/?message=world&time=now")
    logger.call request
    str = File.read("kemal.log")
    File.delete("kemal.log")
    str.includes?("GET /?message=world&time=now").should eq false
  end
end
