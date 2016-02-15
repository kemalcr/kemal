require "../spec_helper"

describe "Kemal::Middleware::Filters" do
  it "executes code before home request" do
    test_filter = FilterTest.new
    test_filter.modified = "false"

    filter = Kemal::Middleware::Filter.new
    filter.add("GET", "/greetings", :before) { test_filter.modified = "true" }

    kemal = Kemal::RouteHandler.new
    kemal.add_route "GET", "/greetings" { test_filter.modified }

    test_filter.modified.should eq("false")
    request = HTTP::Request.new("GET", "/greetings")
    create_request_and_return_io(filter, request)
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.body.should eq("true")
  end
end

class FilterTest
  property modified
end
