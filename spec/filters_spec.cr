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

  context "HEAD requests served by the GET route" do
    it "runs before_get filters so HEAD cannot bypass them" do
      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("GET", "/admin/*", :before) do |env|
        unless env.request.headers["Authorization"]? == "Bearer s3cret"
          halt env, status_code: 401, response: "Unauthorized"
        end
      end
      Kemal.config.add_filter_handler(filter_handler)

      handler_ran = false
      get "/admin/users" do
        handler_ran = true
        "users"
      end

      # No explicit HEAD route exists, so the GET handler serves this request.
      # The GET filters have to guard it just like they guard a plain GET.
      request = HTTP::Request.new("HEAD", "/admin/users")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(401)
      handler_ran.should be_false
    end

    it "runs after_get filters so HEAD is not missing from audit logs" do
      calls = [] of String

      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("GET", "/admin/*", :after) do |_env|
        calls << "after_get"
      end
      Kemal.config.add_filter_handler(filter_handler)

      get "/admin/users" do
        calls << "handler"
        "users"
      end

      request = HTTP::Request.new("HEAD", "/admin/users")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      calls.should eq(["handler", "after_get"])
    end

    it "runs filters registered for the HEAD verb alongside the GET filters" do
      calls = [] of String

      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("HEAD", "/admin/*", :before) do |_env|
        calls << "before_head"
      end
      filter_handler._add_route_filter("GET", "/admin/*", :before) do |_env|
        calls << "before_get"
      end
      Kemal.config.add_filter_handler(filter_handler)

      get "/admin/users" do
        calls << "handler"
        "users"
      end

      # Picking up the GET filters must not drop the ones registered for HEAD.
      request = HTTP::Request.new("HEAD", "/admin/users")
      call_request_on_app(request).status_code.should eq(200)
      calls.should eq(["before_head", "before_get", "handler"])
    end

    it "keeps the HEAD verb for an explicit HEAD route" do
      calls = [] of String

      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("GET", "/admin/*", :before) do |_env|
        calls << "before_get"
      end
      filter_handler._add_route_filter("HEAD", "/admin/*", :before) do |_env|
        calls << "before_head"
      end
      Kemal.config.add_filter_handler(filter_handler)

      Kemal::RouteHandler::INSTANCE.add_route("HEAD", "/admin/users") { "" }
      get "/admin/users" do
        "users"
      end

      request = HTTP::Request.new("HEAD", "/admin/users")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      calls.should eq(["before_head"])
    end

    it "still runs the GET filters for a plain GET request" do
      calls = [] of String

      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("GET", "/admin/*", :before) do |_env|
        calls << "before_get"
      end
      filter_handler._add_route_filter("GET", "/admin/*", :after) do |_env|
        calls << "after_get"
      end
      Kemal.config.add_filter_handler(filter_handler)

      get "/admin/users" do
        calls << "handler"
        "users"
      end

      request = HTTP::Request.new("GET", "/admin/users")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.body.should eq("users")
      calls.should eq(["before_get", "handler", "after_get"])
    end
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
