require "./spec_helper"

describe "Context" do
  it "has a default content type" do
    get "/" do |env|
      "Hello"
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.headers["Content-Type"].should eq("text/html")
  end

  it "sets content type" do
    get "/" do |env|
      env.response.content_type = "application/json"
      "Hello"
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.headers["Content-Type"].should eq("application/json")
  end

  it "parses headers" do
    get "/" do |env|
      name = env.request.headers["name"]
      "Hello #{name}"
    end
    headers = HTTP::Headers.new
    headers["name"] = "kemal"
    request = HTTP::Request.new("GET", "/", headers)
    client_response = call_request_on_app(request)
    client_response.body.should eq "Hello kemal"
  end

  it "sets response headers" do
    get "/" do |env|
      env.response.headers.add "Accept-Language", "tr"
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.headers["Accept-Language"].should eq "tr"
  end
end
