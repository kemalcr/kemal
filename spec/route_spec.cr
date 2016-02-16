require "./spec_helper"

describe "Route" do
  describe "match?" do
    it "matches the correct route" do
      kemal = Kemal::RouteHandler::INSTANCE
      kemal.add_route "GET", "/route1" do |env|
        "Route 1"
      end
      kemal.add_route "GET", "/route2" do |env|
        "Route 2"
      end
      request = HTTP::Request.new("GET", "/route2")
      io_with_context = create_request_and_return_io(kemal, request)
      client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
      client_response.body.should eq("Route 2")
    end
  end
end
