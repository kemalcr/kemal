require "./spec_helper"

describe "Context" do
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

  it "can store variables" do
    before_get "/" do |env|
      env.set "before_get", "Kemal"
      env.set "before_get_int", 123
      env.set "before_get_float", 3.5
    end

    get "/" do |env|
      env.set "key", "value"
      {
        key:              env.get("key"),
        before_get:       env.get("before_get"),
        before_get_int:   env.get("before_get_int"),
        before_get_float: env.get("before_get_float"),
      }
    end
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::FilterHandler::INSTANCE.call(context)
    Kemal::RouteHandler::INSTANCE.call(context)
    context.store["key"].should eq "value"
    context.store["before_get"].should eq "Kemal"
    context.store["before_get_int"].should eq 123
    context.store["before_get_float"].should eq 3.5
  end
end
