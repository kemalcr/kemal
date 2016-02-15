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

  it "executes code before GET home request but not POST home request" do
    test_filter = FilterTest.new
    test_filter.modified = "false"
    test_post_filter = FilterTest.new
    test_post_filter.modified = "false"

    filter = Kemal::Middleware::Filter.new
    filter.add("GET", "/greetings", :before) { test_filter.modified = "true" }
    filter.add("POST", "/greetings", :before) { test_filter.modified = "true" }

    kemal = Kemal::RouteHandler.new
    kemal.add_route "GET", "/greetings" { test_filter.modified }
    kemal.add_route "POST", "/greetings" { test_post_filter.modified }

    test_filter.modified.should eq("false")
    test_post_filter.modified.should eq("false")

    request = HTTP::Request.new("GET", "/greetings")
    create_request_and_return_io(filter, request)
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.body.should eq("true")

    request = HTTP::Request.new("POST", "/greetings")
    create_request_and_return_io(filter, request)
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.body.should eq("false")
  end

end

class FilterTest
  property modified
end
