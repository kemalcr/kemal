require "./spec_helper"

describe "Kemal::OverrideMethodHandler" do
  it "does not override method without _method for POST requests" do
    request = HTTP::Request.new(
      "POST",
      "/",
      body: "_not_method=PATCH",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8"}
    )

    context = create_request_and_return_io_and_context(Kemal::OverrideMethodHandler::INSTANCE, request)[1]

    context.request.method.should eq "POST"
  end

  it "overrides method with _method for POST requests" do
    request = HTTP::Request.new(
      "POST",
      "/",
      body: "_method=PATCH",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8"}
    )

    context = create_request_and_return_io_and_context(Kemal::OverrideMethodHandler::INSTANCE, request)[1]

    context.request.method.should eq "PATCH"
  end
end
