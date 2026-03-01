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

  it "routes POST with _method=PUT to PUT handler in real app" do
    use Kemal::OverrideMethodHandler::INSTANCE

    put "/items/:id" do |env|
      "updated #{env.params.url["id"]}"
    end

    request = HTTP::Request.new(
      "POST",
      "/items/42",
      body: "_method=PUT",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8"}
    )

    response = call_request_on_app(request)

    response.status_code.should eq 200
    response.body.should eq "updated 42"
  end

  it "does not override method when _method is not allowed" do
    use Kemal::OverrideMethodHandler::INSTANCE

    post "/items/:id" do |env|
      "posted #{env.params.url["id"]}"
    end

    put "/items/:id" do |env|
      "updated #{env.params.url["id"]}"
    end

    request = HTTP::Request.new(
      "POST",
      "/items/42",
      body: "_method=TRACE",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8"}
    )

    response = call_request_on_app(request)

    response.status_code.should eq 200
    response.body.should eq "posted 42"
  end
end
