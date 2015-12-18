require "./spec_helper"

macro render_with_base_and_layout(filename)
  render "spec/asset/#{{{filename}}}", "spec/asset/layout.ecr"
end

describe "Views" do
  it "renders file" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/view/:name" do |env|
      render "spec/asset/hello.ecr"
    end
    request = HTTP::Request.new("GET", "/view/world")
    response = kemal.call(request)
    response.body.should contain("Hello world")
  end

  it "renders file with dynamic variables" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/view/:name" do |env|
      render_with_base_and_layout "hello.ecr"
    end
    request = HTTP::Request.new("GET", "/view/world")
    response = kemal.call(request)
    response.body.should contain("Hello world")
  end

  it "renders layout" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/view/:name" do |env|
      render "spec/asset/hello.ecr", "spec/asset/layout.ecr"
    end
    request = HTTP::Request.new("GET", "/view/world")
    response = kemal.call(request)
    response.body.should contain("<html>Hello world")
  end
end
