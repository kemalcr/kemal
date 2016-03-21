require "./spec_helper"

macro render_with_base_and_layout(filename)
  render "spec/asset/#{{{filename}}}", "spec/asset/layout.ecr"
end

describe "Views" do
  it "renders file" do
    get "/view/:name" do |env|
      name = env.params.url["name"]
      render "spec/asset/hello.ecr"
    end
    request = HTTP::Request.new("GET", "/view/world")
    client_response = call_request_on_app(request)
    client_response.body.should contain("Hello world")
  end

  it "renders file with dynamic variables" do
    get "/view/:name" do |env|
      name = env.params.url["name"]
      render_with_base_and_layout "hello.ecr"
    end
    request = HTTP::Request.new("GET", "/view/world")
    client_response = call_request_on_app(request)
    client_response.body.should contain("Hello world")
  end

  it "renders layout" do
    get "/view/:name" do |env|
      name = env.params.url["name"]
      render "spec/asset/hello.ecr", "spec/asset/layout.ecr"
    end
    request = HTTP::Request.new("GET", "/view/world")
    client_response = call_request_on_app(request)
    client_response.body.should contain("<html>Hello world")
  end
end
