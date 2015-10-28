require "./spec_helper"

describe "Route" do
  describe "match" do
    it "doesn't match because of route" do
      route = Route.new("GET", "/foo/bar") { "" }
      request = HTTP::Request.new("GET", "/world?message=coco")
      route.match?(request).should be_nil
    end

    it "doesn't match because of method" do
      route = Route.new("GET", "/foo/bar") { "" }
      request = HTTP::Request.new("POST", "/foo/bar")
      route.match?(request).should be_nil
    end

    it "matches" do
      route = Route.new("GET", "/foo/:one/path/:two") { "" }
      request = HTTP::Request.new("GET", "/foo/uno/path/dos")
      match = route.match?(request)
      match.should eq true
    end
  end
end
