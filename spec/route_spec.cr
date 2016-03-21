require "./spec_helper"

describe "Route" do
  describe "match?" do
    it "matches the correct route" do
      get "/route1" do |env|
        "Route 1"
      end
      get "/route2" do |env|
        "Route 2"
      end
      request = HTTP::Request.new("GET", "/route2")
      client_response = call_request_on_app(request)
      client_response.body.should eq("Route 2")
    end
  end
end
