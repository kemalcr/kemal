require "./spec_helper"

# Kemal's top-level `before_all`/`after_all` shadow the `describe` hooks of the
# spec library. Inside a `describe` they must behave as the spec hooks: run once
# around the group's examples, never register a request filter.
AFTER_ALL_RAN = [] of Symbol

describe "before_all inside a describe" do
  runs = 0

  before_all do
    runs += 1
  end

  after_all do
    AFTER_ALL_RAN << :ran
  end

  it "has run once before the first example" do
    runs.should eq(1)
  end

  it "does not run again for the next example" do
    runs.should eq(1)
  end

  it "registered no request filter" do
    # A filter would have run for this request and bumped the counter.
    get("/") { "ok" }
    call_request_on_app(HTTP::Request.new("GET", "/")).body.should eq("ok")
    runs.should eq(1)
  end
end

describe "after_all inside a describe" do
  it "has run once the previous group finished" do
    AFTER_ALL_RAN.should eq([:ran])
  end
end

describe "before_all outside a describe body" do
  it "registers a request filter when called from an example" do
    # Examples run after every `describe` block has been evaluated, so this is
    # not a `describe` body; it is Kemal's filter, as in an application file.
    before_all do |env|
      env.response.headers["X-Filtered"] = "1"
    end
    get("/") { "ok" }

    call_request_on_app(HTTP::Request.new("GET", "/")).headers["X-Filtered"].should eq("1")
  end
end
