require "./spec_helper"

describe "Request" do
  it "uses the last method override provided" do
    request = HTTP::Request.new(
      "POST",
      "/",
      body: "_method=PUT&_method=PATCH",
      headers: HTTP::Headers{"Content-Type": "application/x-www-form-urlencoded"},
    )

    request.override_method.should eq("PATCH")
  end
end
