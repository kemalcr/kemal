require "./spec_helper"

describe "Kemal::HeadRequestHandler" do
  it "implicitly handles GET endpoints, with Content-Length header" do
    get "/" do
      "hello"
    end
    request = HTTP::Request.new("HEAD", "/")
    client_response = call_request_on_app(request)
    client_response.body.should eq("")
    client_response.headers["Content-Length"].should eq("5")
  end

  it "prefers explicit HEAD endpoint if specified" do
    Kemal::RouteHandler::INSTANCE.add_route("HEAD", "/") { "hello" }
    get "/" do
      raise "shouldn't be called!"
    end
    request = HTTP::Request.new("HEAD", "/")
    client_response = call_request_on_app(request)
    client_response.body.should eq("")
    client_response.headers["Content-Length"].should eq("5")
  end

  it "gives compressed Content-Length when gzip enabled" do
    gzip true
    get "/" do
      "hello"
    end
    headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
    request = HTTP::Request.new("HEAD", "/", headers)
    client_response = call_request_on_app(request)
    client_response.body.should eq("")
    client_response.headers["Content-Encoding"].should eq("gzip")
    client_response.headers["Content-Length"].should eq("25")
  end
end
