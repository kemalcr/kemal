require "./spec_helper"

describe "Logger" do
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
end
