require "./spec_helper"

describe "Route" do
  describe "match?" do
    it "matches the correct route" do
      kemal = Kemal::Handler.new
      kemal.add_route "GET", "/route1" do |env|
        "Route 1"
      end
      kemal.add_route "GET", "/route2" do |env|
        "Route 2"
      end
      request = HTTP::Request.new("GET", "/route2")
      response = kemal.call(request)
      response.body.should eq("Route 2")
    end
  end
end
