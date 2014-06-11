require "spec_helper"

describe "Route" do
  describe "match" do
    it "doesn't match" do
      route = Route.new("/foo/bar", nil)
      route.match(nil, "/foo/baz".split("/")).should be_nil
    end

    it "matches" do
      route = Route.new("/foo/:one/path/:two", nil)
      request = route.match(nil, "/foo/uno/path/dos".split("/"))
      request.not_nil!.params.should eq({"one" => "uno", "two" => "dos"})
    end
  end
end
