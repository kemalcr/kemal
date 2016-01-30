require "./spec_helper"

describe "Kemal::Filter" do
  it "executes code before home request" do
    test_filter = TestFilter.new
    test_filter.modified = "false"

    kemal = Kemal::Handler.new
    kemal.add_filter :before, "*" do
      test_filter.modified = "true"
    end
    kemal.add_route "GET", "/greetings" { test_filter.modified }

    test_filter.modified.should eq("false")
    request = HTTP::Request.new("GET", "/greetings")
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.body.should eq("true")
  end

  it "executes code after home request" do
    test_filter = TestFilter.new
    test_filter.modified = "false"

    kemal = Kemal::Handler.new
    kemal.add_filter :after, "*" do
      test_filter.modified = "true"
    end
    kemal.add_route "GET", "/greetings" { test_filter.modified }

    request = HTTP::Request.new("GET", "/greetings")
    io_with_context = create_request_and_return_io(kemal, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.body.should eq("false")
    test_filter.modified.should eq("true")
  end
end

class TestFilter
  property modified
end
