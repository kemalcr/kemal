require "./spec_helper"

describe "Frank::Handler" do
  it "routes" do
    frank = Frank::Handler.new
    frank.add_route "GET", "/" do
      "hello"
    end
    request = HTTP::Request.new("GET", "/")
    response = frank.call(request)
    response.body.should eq("hello")
  end

  it "sets content type" do
    frank = Frank::Handler.new
    frank.add_route "GET", "/" do |env|
      env.response.content_type = "application/json"
    end
    request = HTTP::Request.new("GET", "/")
    response = frank.call(request)
    response.headers["Content-Type"].should eq("application/json")
  end
end
