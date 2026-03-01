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

  it "routes PUT request via _method override through full handler chain" do
    use Kemal::OverrideMethodHandler::INSTANCE

    error 404 do |env|
      "not found"
    end

    put "/items/:id" do |env|
      "put #{env.params.url["id"]}"
    end

    request = HTTP::Request.new(
      "POST",
      "/items/42",
      body: "_method=PUT&name=test",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}
    )

    response = call_request_on_app(request)

    # BUG: OverrideMethodHandler accesses context.params.body which triggers
    # route_lookup caching with the original POST method. The cached lookup
    # is then reused by RouteHandler, which never sees the overridden PUT method.
    {response.status_code, response.body}.should eq({200, "put 42"})
  end
end
