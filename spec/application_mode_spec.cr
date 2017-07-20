require "./spec_helper"

private class MyApp < Kemal::Application
  get "/route1" do |env|
    "Route 1"
  end

  get "/route2" do |env|
    "Route 2"
  end

  get "/file" do |env|
    send_file env, "Serdar".to_slice
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

  it "sends file with binary stream" do
    request = HTTP::Request.new("GET", "/file")
    response = call_request_on_app(MyApp.new, request)
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq("application/octet-stream")
    response.headers["Content-Length"].should eq("6")
  end

  it "responds to delayed route" do
    app = MyApp.new
    app.setup
    app.get "/delayed" do |env|
      "Happy addition!"
    end
    request = HTTP::Request.new("GET", "/delayed")
    client_response = call_request_on_app(app, request)
    client_response.body.should eq("Happy addition!")
  end
end
