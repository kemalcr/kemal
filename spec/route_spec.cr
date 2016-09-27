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

  it "returns json without #to_json if Content-Type is application/json" do
    get "/" do |env|
      env.response.content_type = "application/json"
      {name: "Serdar", skills: ["Crystal", "Ruby"]}
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.body.should eq("{name: \"Serdar\", skills: [\"Crystal\", \"Ruby\"]}")
  end
end
