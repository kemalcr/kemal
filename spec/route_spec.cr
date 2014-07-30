require "spec_helper"

describe "Route" do
  describe "match" do
    it "doesn't match because of route" do
      route = Route.new("GET", "/foo/bar") { "" }
      route.match("GET", "/foo/baz".split("/")).should be_nil
    end

    it "doesn't match because of method" do
      route = Route.new("GET", "/foo/bar") { "" }
      route.match("POST", "/foo/bar".split("/")).should be_nil
    end

    it "matches" do
      route = Route.new("GET", "/foo/:one/path/:two") { "" }
      params = route.match("GET", "/foo/uno/path/dos".split("/"))
      params.should eq({"one" => "uno", "two" => "dos"})
    end
  end
end
