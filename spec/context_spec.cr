require "./spec_helper"

describe "Context" do
  it "has a default content type" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      "Hello"
    end
    request = HTTP::Request.new("GET", "/")
    response = kemal.call(request)
    response.headers["Content-Type"].should eq("text/html")
  end

  it "sets content type" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      env.set_content_type "application/json"
    end
    request = HTTP::Request.new("GET", "/")
    response = kemal.call(request)
    response.headers["Content-Type"].should eq("application/json")
  end

  it "parses headers" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      name = env.headers["name"]
      "Hello #{name}"
    end
    headers = HTTP::Headers.new
    headers["Name"] = "kemal"
    request = HTTP::Request.new("GET", "/", headers)
    response = kemal.call(request)
    response.body.should eq "Hello kemal"
  end
end
