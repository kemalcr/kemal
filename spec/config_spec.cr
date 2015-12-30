require "./spec_helper"

class CustomTestHandler < HTTP::Handler
  def call(request)
    call_next request
  end
end

describe "Config" do
  it "sets default port to 3000" do
    config = Kemal.config
    config.port.should eq 3000
  end

  it "sets default environment to development" do
    config = Kemal.config
    config.env.should eq "development"
  end

  it "set environment to production" do
    config = Kemal.config
    config.env = "production"
    config.env.should eq "production"
  end

  it "adds a custom handler" do
    config = Kemal.config
    config.add_handler CustomTestHandler.new
    config.handlers.size.should eq(1)
  end

  it "sets public folder" do
    public_folder "/some/path/to/folder"
    Kemal.config.public_folder.should eq("/some/path/to/folder")
  end
end
