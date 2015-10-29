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
    kemal.add_route "GET", "/" do |env|
      "hello #{env.params["message"]}"
    end
    request = HTTP::Request.new("GET", "/?message=world")
    response = kemal.call(request)
    response.body.should eq("hello world")
  end

  it "routes request with multiple query strings" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      "hello #{env.params["message"]} time #{env.params["time"]}"
    end
    request = HTTP::Request.new("GET", "/?message=world&time=now")
    response = kemal.call(request)
    response.body.should eq("hello world time now")
  end

  it "route parameter has more precedence than query string arguments" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/:message" do |env|
      "hello #{env.params["message"]}"
    end
    request = HTTP::Request.new("GET", "/world?message=coco")
    response = kemal.call(request)
    response.body.should eq("hello world")
  end
end
