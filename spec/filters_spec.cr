require "./spec_helper"

describe "Kemal::FilterHandler" do
  it "handles with upcased 'POST'" do
    filter_handler = Kemal::FilterHandler.new
    filter_handler._add_route_filter("POST", "*", :before) do |env|
      env.set "sensitive", "1"
    end
    Kemal.config.add_filter_handler(filter_handler)

    post "/sensitive_post" do |env|
      env.get "sensitive"
    end

    request = HTTP::Request.new("POST", "/sensitive_post")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(200)
    client_response.body.should eq("1")
  end

  it "handles with downcased 'post'" do
    filter_handler = Kemal::FilterHandler.new
    filter_handler._add_route_filter("POST", "*", :before) do |env|
      env.set "sensitive", "1"
    end
    Kemal.config.add_filter_handler(filter_handler)

    post "/sensitive_post" do
      "sensitive"
    end

    request = HTTP::Request.new("post", "/sensitive_post")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(200)
    client_response.body.should eq("")
  end

  context "after filters" do
    it "does not crash when modifying headers for large responses (#759)" do
      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("GET", "*", :after) do |env|
        env.response.content_type = "application/json"
      end
      Kemal.config.add_filter_handler(filter_handler)

      # Large enough to overflow the 8KB response output buffer: the headers
      # are flushed to the client before the after filter runs, so the header
      # change raises. The response must still be delivered intact instead of
      # crashing with an unhandled exception (#759).
      body = "a" * 100_000

      get "/big" do
        body
      end

      request = HTTP::Request.new("GET", "/big")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.body.should eq(body)
    end

    it "can modify response headers for small responses" do
      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("GET", "*", :after) do |env|
        env.response.content_type = "application/json"
      end
      Kemal.config.add_filter_handler(filter_handler)

      get "/small" do
        "ok"
      end

      request = HTTP::Request.new("GET", "/small")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.headers["Content-Type"].should eq("application/json")
      client_response.body.should eq("ok")
    end

    it "renders 500 when an after filter raises before the headers are sent" do
      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("GET", "*", :after) do |_env|
        raise "after filter error"
      end
      Kemal.config.add_filter_handler(filter_handler)

      get "/small" do
        "ok"
      end

      request = HTTP::Request.new("GET", "/small")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(500)
    end

    it "delivers the response as-is when an after filter raises after the headers were sent" do
      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("GET", "*", :after) do |_env|
        raise "after filter error"
      end
      Kemal.config.add_filter_handler(filter_handler)

      body = "a" * 100_000

      get "/big" do
        body
      end

      request = HTTP::Request.new("GET", "/big")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.body.should eq(body)
    end

    it "does not crash when the route already streamed the response body" do
      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("GET", "*", :after) do |env|
        env.response.content_type = "application/json"
      end
      Kemal.config.add_filter_handler(filter_handler)

      body = "b" * 100_000

      get "/stream" do |env|
        env.response.print(body)
        ""
      end

      request = HTTP::Request.new("GET", "/stream")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.body.should eq(body)
    end
  end
end
