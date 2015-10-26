require "./spec_helper"

describe "Kemal::Handler" do
  it "routes" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do
      "hello"
    end
    request = HTTP::Request.new("GET", "/")
    response = kemal.call(request)
    response.body.should eq("hello")
  end

  it "routes request with query string" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |ctx|
      "hello #{ctx.params["message"]}"
    end
    request = HTTP::Request.new("GET", "/?message=world")
    response = kemal.call(request)
    response.body.should eq("hello world")
  end

  it "route parameter has more precedence than query string arguments" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/:message" do |ctx|
      "hello #{ctx.params["message"]}"
    end
    request = HTTP::Request.new("GET", "/world?message=coco")
    response = kemal.call(request)
    response.body.should eq("hello world")
  end

  it "sets content type" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      env.response.content_type = "application/json"
    end
    request = HTTP::Request.new("GET", "/")
    response = kemal.call(request)
    response.headers["Content-Type"].should eq("application/json")
  end

  it "parses POST body" do
    kemal = Kemal::Handler.new
    kemal.add_route "POST", "/" do |env|
      name = env.request.params["name"]
      age = env.request.params["age"]
      hasan = env.request.params["hasan"]
      "Hello #{name} #{hasan} #{age}"
    end
    request = HTTP::Request.new("POST", "/?hasan=cemal", body: "name=kemal&age=99")
    response = kemal.call(request)
    response.body.should eq("Hello kemal cemal 99")
  end
end
