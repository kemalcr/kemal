require "./spec_helper"

describe "Context" do
  it "has a default content type" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      "Hello"
    end
    request = HTTP::Request.new("GET", "/")
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.headers["Content-Type"].should eq("text/html")
  end

  it "sets content type" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      env.response.content_type = "application/json"
      "Hello"
    end
    request = HTTP::Request.new("GET", "/")
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.headers["Content-Type"].should eq("application/json")
  end

  it "parses headers" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      name = env.request.headers["name"]
      "Hello #{name}"
    end
    headers = HTTP::Headers.new
    headers["name"] = "kemal"
    request = HTTP::Request.new("GET", "/", headers)
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.body.should eq "Hello kemal"
  end

  it "sets response headers" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      env.response.headers.add "Accept-Language", "tr"
    end
    request = HTTP::Request.new("GET", "/")
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.headers["Accept-Language"].should eq "tr"
  end
end
