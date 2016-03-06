require "./spec_helper"

macro render_with_base_and_layout(filename)
  render "spec/asset/#{{{filename}}}", "spec/asset/layout.ecr"
end

describe "Views" do
  it "renders file" do
    kemal = Kemal::RouteHandler::INSTANCE
    kemal.add_route "GET", "/view/:name" do |env|
      name = env.params.url["name"]
      render "spec/asset/hello.ecr"
    end
    request = HTTP::Request.new("GET", "/view/world")
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.body.should contain("Hello world")
  end

  it "renders file with dynamic variables" do
    kemal = Kemal::RouteHandler::INSTANCE
    kemal.add_route "GET", "/view/:name" do |env|
      name = env.params.url["name"]
      render_with_base_and_layout "hello.ecr"
    end
    request = HTTP::Request.new("GET", "/view/world")
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.body.should contain("Hello world")
  end

  it "renders layout" do
    kemal = Kemal::RouteHandler::INSTANCE
    kemal.add_route "GET", "/view/:name" do |env|
      name = env.params.url["name"]
      render "spec/asset/hello.ecr", "spec/asset/layout.ecr"
    end
    request = HTTP::Request.new("GET", "/view/world")
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.body.should contain("<html>Hello world")
  end
end
