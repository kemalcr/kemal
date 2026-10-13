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

  it "treats a downcased 'post' as unrouted" do
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
    # HTTP methods are case sensitive (RFC 9110 §9.1), so `post` matches no
    # route. The path is routed for `POST`, which makes this a 405 rather than
    # a 404.
    client_response.status_code.should eq(405)
    client_response.headers["Allow"].should eq("POST")
    client_response.body.should eq("Method Not Allowed")
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

  it "runs before_all for an unmatched path whether or not an error handler is registered" do
    # `Kemal.run` registers an `error 404` outside the `test` environment and
    # nothing does inside it; `before_all` used to run only when one existed, so
    # an authentication guard ran in production and not under spec.
    Kemal.config.error_handlers.has_key?(404).should be_false

    filter_handler = Kemal::FilterHandler.new
    filter_handler._add_route_filter("ALL", "*", :before) do |env|
      env.response.headers["X-Seen"] = "1"
    end
    Kemal.config.add_filter_handler(filter_handler)

    response = call_request_on_app(HTTP::Request.new("GET", "/nope"))
    response.status_code.should eq(404)
    response.headers["X-Seen"].should eq("1")
  end

  it "lets before_all answer an unmatched path itself" do
    filter_handler = Kemal::FilterHandler.new
    filter_handler._add_route_filter("ALL", "*", :before) do |env|
      halt env, status_code: 401, response: "auth required"
    end
    Kemal.config.add_filter_handler(filter_handler)

    response = call_request_on_app(HTTP::Request.new("GET", "/nope"))
    response.status_code.should eq(401)
    response.body.should eq("auth required")
  end

  context "a WebSocket handshake" do
    it "runs before_get filters" do
      reached = false
      before_get "/chat" do |env|
        halt env, status_code: 401, response: "auth required"
      end
      ws "/chat" { reached = true }

      request = HTTP::Request.new("GET", "/chat", ws_upgrade_headers_for_origin("http://localhost"))
      io = create_ws_request_and_return_io_and_context(build_main_handler, request)[0]
      io.to_s.should start_with("HTTP/1.1 401 Unauthorized")
      reached.should be_false
    end

    it "renders the error handler for a status a before filter set" do
      error 401 { "nope" }
      before_get("/chat", &.response.status_code=(401))
      ws "/chat" { }

      response = call_request_on_app(HTTP::Request.new("GET", "/chat", ws_upgrade_headers_for_origin("http://localhost")))
      response.status_code.should eq(401)
      response.body.should eq("nope")
    end

    it "leaves after filters out once the upgrade is on the wire" do
      ran = false
      after_get "/chat" { ran = true }
      ws "/chat" { }

      request = HTTP::Request.new("GET", "/chat", ws_upgrade_headers_for_origin("http://localhost"))
      io = create_ws_request_and_return_io_and_context(build_main_handler, request)[0]
      io.to_s.should contain("101 Switching Protocols")
      ran.should be_false
    end

    it "is told apart from a plain GET to the same path" do
      ran = false
      before_get "/chat" { ran = true }
      ws "/chat" { }

      call_request_on_app(HTTP::Request.new("GET", "/chat")).status_code.should eq(404)
      ran.should be_false
    end
  end

  # A method holding a `/` used to pick the route it resolved to while leaving
  # `request.path` pointing somewhere else, so a path-scoped filter never
  # recognized the request as one of its own (#820).
  context "a request method that is not an RFC 9110 token" do
    it "cannot step around a prefix-scoped before filter" do
      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("ALL", "/admin/*", :before) do |env|
        halt env, status_code: 401, response: "auth required"
      end
      Kemal.config.add_filter_handler(filter_handler)

      get "/admin/secret" do
        "TOP-SECRET-DATA"
      end

      call_request_on_app(HTTP::Request.new("GET", "/admin/secret")).status_code.should eq(401)

      response = call_request_on_app(crafted_method_request("GET/admin", "/secret"))
      response.status_code.should eq(400)
      response.body.should_not contain("TOP-SECRET-DATA")
    end

    it "cannot step around an exact-path before filter" do
      filter_handler = Kemal::FilterHandler.new
      filter_handler._add_route_filter("GET", "/account", :before) do |env|
        halt env, status_code: 401, response: "auth required"
      end
      Kemal.config.add_filter_handler(filter_handler)

      get "/account" do
        "ACCOUNT-DATA"
      end

      call_request_on_app(HTTP::Request.new("GET", "/account")).status_code.should eq(401)

      response = call_request_on_app(crafted_method_request("GET/account", "/"))
      response.status_code.should eq(400)
      response.body.should_not contain("ACCOUNT-DATA")
    end
  end

  # Path filters used to share one radix tree, which runs the single best
  # match for the request path: a more specific filter path hid a broader
  # guard on the same request.
  context "overlapping top-level path filters" do
    it "runs a glob guard next to a more specific static filter" do
      before_all "/api/*" do |env|
        halt env, status_code: 401, response: "auth required"
      end
      before_all "/api/public" do |env|
        env.response.headers["X-Public"] = "1"
      end
      get "/api/public" { "PUBLIC" }
      get "/api/secret" { "SECRET" }

      call_request_on_app(HTTP::Request.new("GET", "/api/public")).status_code.should eq(401)
      call_request_on_app(HTTP::Request.new("GET", "/api/secret")).status_code.should eq(401)
    end

    it "runs a param guard next to a static filter on one of its paths" do
      before_get "/users/:id" do |env|
        halt env, status_code: 401, response: "auth required"
      end
      before_get "/users/me" do |env|
        env.response.headers["X-Me"] = "1"
      end
      get "/users/:id" { "USER" }

      response = call_request_on_app(HTTP::Request.new("GET", "/users/me"))
      response.status_code.should eq(401)
    end

    it "runs both filters on paths that differ by a trailing slash" do
      before_all "/admin/" do |env|
        halt env, status_code: 401, response: "auth required"
      end
      before_all "/admin" do |env|
        env.response.headers["X-Admin"] = "1"
      end
      get "/admin" { "ADMIN" }

      response = call_request_on_app(HTTP::Request.new("GET", "/admin"))
      response.status_code.should eq(401)
    end

    it "runs a glob guard next to a filter on its own prefix" do
      before_all "/admin/*" do |env|
        halt env, status_code: 401, response: "auth required"
      end
      before_all "/admin/" do |env|
        env.response.headers["X-Admin"] = "1"
      end
      get "/admin" { "ADMIN" }

      call_request_on_app(HTTP::Request.new("GET", "/admin")).status_code.should eq(401)
    end

    it "runs a filter path whose key the shared tree split" do
      calls = [] of String
      before_get "/users/:id" { calls << "user" }
      before_get "/users/:uid/posts" { calls << "posts" }
      get "/users/:id" { "USER" }
      get "/users/:id/posts" { "POSTS" }

      call_request_on_app(HTTP::Request.new("GET", "/users/5"))
      call_request_on_app(HTTP::Request.new("GET", "/users/5/posts"))
      calls.should eq(["user", "posts"])
    end

    it "stops at a path filter that halts" do
      later_ran = false
      after_all_ran = false
      before_all "/api/*" do |env|
        halt env, status_code: 401, response: "auth required"
      end
      before_all "/api/public" do |env|
        later_ran = true
        env.response.content_type = "application/json"
      end
      after_all { after_all_ran = true }
      get "/api/public" { "PUBLIC" }

      response = call_request_on_app(HTTP::Request.new("GET", "/api/public"))
      response.status_code.should eq(401)
      response.body.should eq("auth required")
      later_ran.should be_false
      after_all_ran.should be_true
    end

    it "runs every matching after filter" do
      calls = [] of String
      after_get "/reports/*" { calls << "glob" }
      after_get "/reports/:id" { calls << "param" }
      after_get "/reports/daily" { calls << "static" }
      get "/reports/:id" { calls << "handler"; "REPORT" }

      call_request_on_app(HTTP::Request.new("GET", "/reports/daily"))
      calls.should eq(["handler", "glob", "param", "static"])
    end

    it "runs every matching GET filter for a HEAD served by the GET route" do
      before_get "/admin/*" do |env|
        halt env, status_code: 401, response: "auth required"
      end
      before_get "/admin/users" do |env|
        env.response.headers["X-Users"] = "1"
      end
      handler_ran = false
      get "/admin/users" { handler_ran = true; "users" }

      response = call_request_on_app(HTTP::Request.new("HEAD", "/admin/users"))
      response.status_code.should eq(401)
      handler_ran.should be_false
    end

    it "runs every matching before_all filter for an unrouted request" do
      before_all "/api/*" do |env|
        halt env, status_code: 401, response: "auth required"
      end
      before_all "/api/nope" do |env|
        env.response.headers["X-Nope"] = "1"
      end

      response = call_request_on_app(HTTP::Request.new("GET", "/api/nope"))
      response.status_code.should eq(401)
    end

    it "runs global filters first, then path filters in the order their paths were registered" do
      calls = [] of String
      before_get "/orders/me" { calls << "static 1" }
      before_get "/orders/*" { calls << "glob" }
      before_get "*" { calls << "global" }
      before_get "/orders/:id" { calls << "param" }
      before_get "/orders/me" { calls << "static 2" }
      before_get "/orders/other" { calls << "unmatched" }
      get "/orders/:id" { calls << "handler"; "ORDER" }

      call_request_on_app(HTTP::Request.new("GET", "/orders/me"))
      calls.should eq(["global", "static 1", "static 2", "glob", "param", "handler"])
    end
  end
end
