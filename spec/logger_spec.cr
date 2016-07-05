require "./spec_helper"

describe "Kemal::LogHandler" do
  it "creates a handler" do
    logger = Kemal::CommonLogHandler.new
    logger.handler.should_not be nil
  end

  it "creates a STDOUT handler by default" do
    config = Kemal.config
    logger = Kemal::CommonLogHandler.new
    logger.handler.should be_a IO
  end
end
