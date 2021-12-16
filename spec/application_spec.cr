require "./spec_helper"

class TestApplication < Kemal::Application
  get "/abc123" do
    "hello world"
  end
end

describe Kemal::Application do
  it "can define routes that are not applied to global application" do
    test_application = TestApplication.new

    Kemal::GLOBAL_APPLICATION.route_handler.routes.find("/get/abc123").found?.should be_false
    test_application.route_handler.routes.find("/get/abc123").found?.should be_true
  end
end
