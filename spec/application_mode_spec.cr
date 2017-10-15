require "./spec_helper"

private class MyApp < Kemal::Application
  get "/route1" do |env|
    "Route 1"
  end

  get "/route2" do |env|
    "Route 2"
  end
end

describe MyApp do
  it "matches the correct route" do
    request = HTTP::Request.new("GET", "/route2")
    client_response = call_request_on_app(MyApp.new, request)
    client_response.body.should eq("Route 2")
  end

  it "doesn't allow a route declaration start without /" do
    expect_raises Kemal::Exceptions::InvalidPathStartException, "Route declaration get \"route\" needs to start with '/', should be get \"/route\"" do
      MyApp.new.get "route" do |env|
        "Route 1"
      end
    end
  end
end
