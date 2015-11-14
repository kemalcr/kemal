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

  it "adds a custom handler" do
    config = Kemal.config
    config.add_handler CustomTestHandler.new
    config.handlers.size.should eq(1)
  end
end
