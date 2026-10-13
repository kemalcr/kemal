require "./spec_helper"

private def handshake_response(path : String) : String
  request = HTTP::Request.new("GET", path, ws_upgrade_headers_for_origin("http://localhost"))
  create_ws_request_and_return_io_and_context(build_main_handler, request)[0].to_s
end

describe "Kemal::Router" do
  describe "basic routing" do
    it "routes GET request with prefix" do
      router = Kemal::Router.new
      router.get "/users" do
        "users list"
      end

      mount "/api", router

      request = HTTP::Request.new("GET", "/api/users")
      client_response = call_request_on_app(request)
      client_response.body.should eq("users list")
    end

    it "routes POST request with prefix" do
      router = Kemal::Router.new
      router.post "/users" do
        "user created"
      end

      mount "/api", router

      request = HTTP::Request.new("POST", "/api/users")
      client_response = call_request_on_app(request)
      client_response.body.should eq("user created")
    end

    it "routes PUT request with prefix" do
      router = Kemal::Router.new
      router.put "/users/:id" do |env|
        "user #{env.params.url["id"]} updated"
      end

      mount "/api", router

      request = HTTP::Request.new("PUT", "/api/users/123")
      client_response = call_request_on_app(request)
      client_response.body.should eq("user 123 updated")
    end

    it "routes DELETE request with prefix" do
      router = Kemal::Router.new
      router.delete "/users/:id" do |env|
        "user #{env.params.url["id"]} deleted"
      end

      mount "/api", router

      request = HTTP::Request.new("DELETE", "/api/users/456")
      client_response = call_request_on_app(request)
      client_response.body.should eq("user 456 deleted")
    end

    it "routes PATCH request" do
      router = Kemal::Router.new
      router.patch "/users/:id" do
        "user patched"
      end

      mount "/api", router

      request = HTTP::Request.new("PATCH", "/api/users/1")
      client_response = call_request_on_app(request)
      client_response.body.should eq("user patched")
    end

    it "routes OPTIONS request" do
      router = Kemal::Router.new
      router.options "/users" do |env|
        env.response.headers["Allow"] = "GET, POST, OPTIONS"
        ""
      end

      mount "/api", router

      request = HTTP::Request.new("OPTIONS", "/api/users")
      client_response = call_request_on_app(request)
      client_response.headers["Allow"].should eq("GET, POST, OPTIONS")
    end

    it "routes QUERY request with prefix" do
      router = Kemal::Router.new
      router.query "/users/search" do |env|
        "searching for #{env.params.body["q"]}"
      end

      mount "/api", router

      request = HTTP::Request.new(
        "QUERY",
        "/api/users/search",
        body: "q=kemal",
        headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      )
      client_response = call_request_on_app(request)
      client_response.body.should eq("searching for kemal")
    end

    it "mounts router without prefix" do
      router = Kemal::Router.new
      router.get "/status" do
        "ok"
      end

      mount router

      request = HTTP::Request.new("GET", "/status")
      client_response = call_request_on_app(request)
      client_response.body.should eq("ok")
    end

    it "works alongside global DSL routes" do
      # Global DSL route
      get "/global" do
        "global route"
      end

      # Router route
      router = Kemal::Router.new
      router.get "/local" do
        "router route"
      end

      mount "/api", router

      # Test global route
      global_request = HTTP::Request.new("GET", "/global")
      global_response = call_request_on_app(global_request)
      global_response.body.should eq("global route")

      # Test router route
      router_request = HTTP::Request.new("GET", "/api/local")
      router_response = call_request_on_app(router_request)
      router_response.body.should eq("router route")
    end
  end

  describe "router-scoped filters" do
    it "applies before filter to router routes" do
      router = Kemal::Router.new

      router.before do |env|
        env.set "filtered", "yes"
      end

      router.get "/test" do |env|
        env.get("filtered").to_s
      end

      mount "/api", router

      request = HTTP::Request.new("GET", "/api/test")
      client_response = call_request_on_app(request)
      client_response.body.should eq("yes")
    end

    it "applies after filter to router routes" do
      router = Kemal::Router.new

      router.after do |env|
        env.response.headers["X-After-Filter"] = "applied"
      end

      router.get "/test" do
        "test"
      end

      mount "/api", router

      request = HTTP::Request.new("GET", "/api/test")
      client_response = call_request_on_app(request)
      client_response.headers["X-After-Filter"].should eq("applied")
    end

    it "applies method-specific before filter" do
      router = Kemal::Router.new

      router.before_post do |env|
        env.set "method", "post"
      end

      router.post "/test" do |env|
        env.get("method").to_s
      end

      router.get "/test" do |env|
        env.get?("method").to_s
      end

      mount "/api", router

      post_request = HTTP::Request.new("POST", "/api/test")
      post_response = call_request_on_app(post_request)
      post_response.body.should eq("post")
    end

    it "applies QUERY-specific before filter" do
      router = Kemal::Router.new

      router.before_query do |env|
        env.set "method", "query"
      end

      router.query "/test" do |env|
        env.get("method").to_s
      end

      router.get "/test" do |env|
        env.get?("method").to_s
      end

      mount "/api", router

      query_request = HTTP::Request.new("QUERY", "/api/test")
      query_response = call_request_on_app(query_request)
      query_response.body.should eq("query")

      get_request = HTTP::Request.new("GET", "/api/test")
      get_response = call_request_on_app(get_request)
      get_response.body.should eq("")
    end

    it "applies filter to specific path" do
      router = Kemal::Router.new

      router.before "/protected" do |env|
        env.set "auth", "required"
      end

      router.get "/protected" do |env|
        env.get("auth").to_s
      end

      router.get "/public" do |env|
        env.get?("auth").to_s
      end

      mount "/api", router

      protected_request = HTTP::Request.new("GET", "/api/protected")
      protected_response = call_request_on_app(protected_request)
      protected_response.body.should eq("required")
    end

    it "applies a filter registered with \"/*\" to every router route" do
      router = Kemal::Router.new

      router.before "/*" do |env|
        env.set "filtered", "yes"
      end

      router.get "/test" do |env|
        env.get("filtered").to_s
      end

      mount "/api", router

      request = HTTP::Request.new("GET", "/api/test")
      client_response = call_request_on_app(request)
      client_response.body.should eq("yes")
    end

    it "scopes a filter with a \"/*\" suffix to that subtree" do
      router = Kemal::Router.new

      router.before "/admin/*" do |env|
        env.set "auth", "required"
      end

      router.get "/admin/users" do |env|
        env.get("auth").to_s
      end

      router.get "/public" do |env|
        env.get?("auth").to_s
      end

      mount "/api", router

      admin_response = call_request_on_app(HTTP::Request.new("GET", "/api/admin/users"))
      admin_response.body.should eq("required")

      public_response = call_request_on_app(HTTP::Request.new("GET", "/api/public"))
      public_response.body.should eq("")
    end

    it "registers a filter once for a path that carries several methods" do
      calls = 0

      router = Kemal::Router.new
      router.before "/admin/*" do |_env|
        calls += 1
        ""
      end

      router.get "/admin/users" do
        "get"
      end

      router.post "/admin/users" do
        "post"
      end

      mount "/api", router

      call_request_on_app(HTTP::Request.new("GET", "/api/admin/users"))
      calls.should eq(1)
    end

    it "guards every router route when before_get is registered with \"/*\"" do
      router = Kemal::Router.new

      router.before_get "/*" do |env|
        unless env.request.headers["Authorization"]? == "Bearer s3cret"
          halt env, status_code: 401, response: "Unauthorized"
        end
      end

      handler_ran = false
      router.get "/secret" do
        handler_ran = true
        "secret"
      end

      mount "/api", router

      # A filter path that silently registered nowhere left the route wide open.
      call_request_on_app(HTTP::Request.new("GET", "/api/secret")).status_code.should eq(401)
      call_request_on_app(HTTP::Request.new("HEAD", "/api/secret")).status_code.should eq(401)
      handler_ran.should be_false

      headers = HTTP::Headers{"Authorization" => "Bearer s3cret"}
      authorized = call_request_on_app(HTTP::Request.new("GET", "/api/secret", headers))
      authorized.status_code.should eq(200)
      authorized.body.should eq("secret")
      handler_ran.should be_true
    end

    it "applies namespace filters only within the namespace" do
      router = Kemal::Router.new

      router.namespace "/admin" do
        before do |env|
          halt env, 401, "unauthorized" unless env.request.headers["X-Admin"]? == "true"
        end

        get "/dashboard" do |env|
          env.get("path").to_s
        end
      end

      router.get "/public" do |env|
        env.get("path").to_s
      end

      mount "/api", router

      before_all do |env|
        env.set "path", env.request.path
      end

      get "/public" do |env|
        env.get("path").to_s
      end

      unauthorized_request = HTTP::Request.new("GET", "/api/admin/dashboard")
      unauthorized_response = call_request_on_app(unauthorized_request)
      unauthorized_response.status_code.should eq(401)
      unauthorized_response.body.should eq("unauthorized")

      authorized_request = HTTP::Request.new(
        "GET",
        "/api/admin/dashboard",
        headers: HTTP::Headers{"X-Admin" => "true"},
      )
      authorized_response = call_request_on_app(authorized_request)
      authorized_response.status_code.should eq(200)
      authorized_response.body.should eq("/api/admin/dashboard")

      api_public_request = HTTP::Request.new("GET", "/api/public")
      api_public_response = call_request_on_app(api_public_request)
      api_public_response.status_code.should eq(200)
      api_public_response.body.should eq("/api/public")

      public_request = HTTP::Request.new("GET", "/public")
      public_response = call_request_on_app(public_request)
      public_response.status_code.should eq(200)
      public_response.body.should eq("/public")
    end
  end

  describe "nested routers" do
    it "namespaces routes correctly" do
      router = Kemal::Router.new

      router.namespace "/users" do
        get "/" do
          "users index"
        end

        get "/:id" do |env|
          "user #{env.params.url["id"]}"
        end
      end

      mount "/api/v1", router

      index_request = HTTP::Request.new("GET", "/api/v1/users")
      index_response = call_request_on_app(index_request)
      index_response.body.should eq("users index")

      show_request = HTTP::Request.new("GET", "/api/v1/users/42")
      show_response = call_request_on_app(show_request)
      show_response.body.should eq("user 42")
    end

    it "supports multiple namespaces" do
      router = Kemal::Router.new

      router.namespace "/users" do
        get "/" do
          "users"
        end
      end

      router.namespace "/posts" do
        get "/" do
          "posts"
        end
      end

      mount "/api", router

      users_request = HTTP::Request.new("GET", "/api/users")
      users_response = call_request_on_app(users_request)
      users_response.body.should eq("users")

      posts_request = HTTP::Request.new("GET", "/api/posts")
      posts_response = call_request_on_app(posts_request)
      posts_response.body.should eq("posts")
    end

    it "supports deeply nested routers" do
      router = Kemal::Router.new

      router.namespace "/api" do
        namespace "/v1" do
          namespace "/users" do
            get "/" do
              "deeply nested users"
            end
          end
        end
      end

      mount router

      request = HTTP::Request.new("GET", "/api/v1/users")
      client_response = call_request_on_app(request)
      client_response.body.should eq("deeply nested users")
    end

    it "mounts sub-router with mount method" do
      users_router = Kemal::Router.new
      users_router.get "/" do
        "users from sub-router"
      end
      users_router.get "/:id" do |env|
        "user #{env.params.url["id"]} from sub-router"
      end

      api_router = Kemal::Router.new
      api_router.mount "/users", users_router

      mount "/api", api_router

      index_request = HTTP::Request.new("GET", "/api/users")
      index_response = call_request_on_app(index_request)
      index_response.body.should eq("users from sub-router")

      show_request = HTTP::Request.new("GET", "/api/users/99")
      show_response = call_request_on_app(show_request)
      show_response.body.should eq("user 99 from sub-router")
    end

    it "applies namespace filters correctly" do
      router = Kemal::Router.new

      router.namespace "/admin" do
        before do |env|
          env.set "admin", "true"
        end

        get "/dashboard" do |env|
          "admin: #{env.get("admin")}"
        end
      end

      mount router

      request = HTTP::Request.new("GET", "/admin/dashboard")
      client_response = call_request_on_app(request)
      client_response.body.should eq("admin: true")
    end
  end

  describe "websocket support" do
    it "registers websocket route with prefix" do
      router = Kemal::Router.new
      router.ws "/chat" do |socket|
        socket.send("connected")
      end

      mount "/ws", router

      handler = Kemal::WebSocketHandler::INSTANCE
      headers = HTTP::Headers{
        "Upgrade"               => "websocket",
        "Connection"            => "Upgrade",
        "Sec-WebSocket-Key"     => "dGhlIHNhbXBsZSBub25jZQ==",
        "Sec-WebSocket-Version" => "13",
        "Host"                  => "localhost",
        "Origin"                => "http://localhost",
      }
      request = HTTP::Request.new("GET", "/ws/chat", headers)

      io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
      io_with_context.to_s.should contain("101 Switching Protocols")
    end

    it "websocket route with url parameters" do
      router = Kemal::Router.new
      router.ws "/room/:id" do |socket|
        socket.send("room")
      end

      mount "/ws", router

      handler = Kemal::WebSocketHandler::INSTANCE
      headers = HTTP::Headers{
        "Upgrade"               => "websocket",
        "Connection"            => "Upgrade",
        "Sec-WebSocket-Key"     => "dGhlIHNhbXBsZSBub25jZQ==",
        "Sec-WebSocket-Version" => "13",
        "Host"                  => "localhost",
        "Origin"                => "http://localhost",
      }
      request = HTTP::Request.new("GET", "/ws/room/123", headers)

      io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
      io_with_context.to_s.should contain("101 Switching Protocols")
    end

    {% for filter in %w[before before_get] %}
      it "guards websocket routes with router.{{ filter.id }}" do
        reached = false
        router = Kemal::Router.new
        router.{{ filter.id }} do |env|
          env.response.status_code = 401
          halt env
        end
        router.ws "/chat" { reached = true }
        router.namespace "/admin" do
          ws "/live" { reached = true }
        end

        mount "/api", router

        {"/api/chat", "/api/admin/live"}.each do |path|
          request = HTTP::Request.new("GET", path, ws_upgrade_headers_for_origin("http://localhost"))
          io = create_ws_request_and_return_io_and_context(build_main_handler, request)[0]
          io.to_s.should start_with("HTTP/1.1 401 Unauthorized")
        end
        reached.should be_false
      end
    {% end %}

    it "leaves websocket routes alone for a filter on another method" do
      router = Kemal::Router.new
      router.before_post do |env|
        env.response.status_code = 401
        halt env
      end
      router.ws "/chat" { }

      mount "/api", router

      request = HTTP::Request.new("GET", "/api/chat", ws_upgrade_headers_for_origin("http://localhost"))
      io = create_ws_request_and_return_io_and_context(build_main_handler, request)[0]
      io.to_s.should contain("101 Switching Protocols")
    end

    it "runs a filter once for routes that name the same param differently" do
      count = 0
      router = Kemal::Router.new
      router.before { count += 1 }
      router.get "/rooms/:id" { "room" }
      router.ws "/rooms/:key" { }

      mount "/api", router

      call_request_on_app(HTTP::Request.new("GET", "/api/rooms/42")).body.should eq("room")
      count.should eq(1)
    end

    it "keeps guarding HTTP routes beside websocket routes with other param names" do
      router = Kemal::Router.new
      router.before do |env|
        env.response.status_code = 401
        halt env
      end
      router.get "/rooms/new" { "secret" }
      router.get "/rooms/:id" { "secret" }
      router.post "/rooms/:room_id" { "secret" }
      router.ws "/rooms/:key" { }
      router.ws "/rooms/:key/socket" { }

      mount "/api", router

      {"/api/rooms/new", "/api/rooms/42"}.each do |path|
        call_request_on_app(HTTP::Request.new("GET", path)).status_code.should eq(401)
      end
      call_request_on_app(HTTP::Request.new("POST", "/api/rooms/42")).status_code.should eq(401)
      {"/api/rooms/42", "/api/rooms/42/socket"}.each do |path|
        request = HTTP::Request.new("GET", path, ws_upgrade_headers_for_origin("http://localhost"))
        io = create_ws_request_and_return_io_and_context(build_main_handler, request)[0]
        io.to_s.should start_with("HTTP/1.1 401 Unauthorized")
      end
    end
  end

  # Router filters used to be keys in `Kemal::FilterHandler`'s radix tree, which
  # runs only the best match for a request path, so a more specific key from
  # anywhere else hid them.
  describe "filters beside other filters on the same paths" do
    it "leaves a top-level glob guard in force over a router with filters of its own" do
      before_all "/api/*" { |env| halt env, status_code: 401 }
      router = Kemal::Router.new
      router.before { }
      router.get "/http" { "secret" }
      router.ws "/live" { }

      mount "/api", router

      call_request_on_app(HTTP::Request.new("GET", "/api/http")).status_code.should eq(401)
      handshake_response("/api/live").should start_with("HTTP/1.1 401 Unauthorized")
    end

    it "keeps a router guard in force beside a more specific top-level filter" do
      before_all "/api/rooms/lobby" { }
      router = Kemal::Router.new
      router.before { |env| halt env, status_code: 401 }
      router.get "/rooms/:id" { "secret" }
      router.ws "/rooms/:id" { }

      mount "/api", router

      call_request_on_app(HTTP::Request.new("GET", "/api/rooms/lobby")).status_code.should eq(401)
      handshake_response("/api/rooms/lobby").should start_with("HTTP/1.1 401 Unauthorized")
    end

    it "guards a handshake with the filters of the router serving it" do
      chat = Kemal::Router.new
      chat.before { |env| halt env, status_code: 401 }
      chat.ws "/chat/:room" { }
      pages = Kemal::Router.new
      pages.before { }
      pages.get "/chat/public" { "page" }

      mount "/api", chat
      mount "/api", pages

      call_request_on_app(HTTP::Request.new("GET", "/api/chat/public")).body.should eq("page")
      handshake_response("/api/chat/public").should start_with("HTTP/1.1 401 Unauthorized")
    end

    it "keeps guarding a trailing-slash route beside a longer sibling" do
      router = Kemal::Router.new
      router.before { |env| halt env, status_code: 401 }
      router.get "/chat/" { "secret" }
      router.post "/chatroom" { "secret" }
      router.ws "/chat/" { }

      mount "/api", router

      call_request_on_app(HTTP::Request.new("GET", "/api/chat/")).status_code.should eq(401)
      handshake_response("/api/chat/").should start_with("HTTP/1.1 401 Unauthorized")
    end

    it "scopes a filter path to routes that name its param differently" do
      router = Kemal::Router.new
      router.before "/rooms/:id" { |env| halt env, status_code: 401 }
      router.get "/rooms/:room_id" { "secret" }
      router.ws "/rooms/:key" { }

      mount "/api", router

      call_request_on_app(HTTP::Request.new("GET", "/api/rooms/42")).status_code.should eq(401)
      handshake_response("/api/rooms/42").should start_with("HTTP/1.1 401 Unauthorized")
    end

    it "matches a filter path against the request path, not the route's spelling" do
      router = Kemal::Router.new
      router.before "/users/:id" { |env| halt env, status_code: 401 }
      router.before "/teams/admin" { |env| halt env, status_code: 403 }
      router.before "/files/*rest" { |env| halt env, status_code: 401 }
      router.before "/admin/" { |env| halt env, status_code: 401 }
      router.get "/users/me" { "secret" }
      router.get "/teams/:id" { "team" }
      router.get "/files/:name" { "secret" }
      router.get "/admin/users" { "secret" }

      mount "/api", router

      {"/api/users/me", "/api/files/a", "/api/admin/users"}.each do |path|
        call_request_on_app(HTTP::Request.new("GET", path)).status_code.should eq(401)
      end
      call_request_on_app(HTTP::Request.new("GET", "/api/teams/admin")).status_code.should eq(403)
      call_request_on_app(HTTP::Request.new("GET", "/api/teams/42")).body.should eq("team")
    end

    it "runs router before filters for a method the router does not serve on the path" do
      router = Kemal::Router.new
      router.before do |env|
        env.response.headers["Access-Control-Allow-Origin"] = "*"
        halt env, status_code: 204 if env.request.method == "OPTIONS"
      end
      router.before "/admin" { |env| halt env, status_code: 401 }
      router.get "/users" { "users" }
      router.get "/admin/:id" { "secret" }

      mount "/api", router

      preflight = call_request_on_app(HTTP::Request.new("OPTIONS", "/api/users"))
      preflight.status_code.should eq(204)
      preflight.headers["Access-Control-Allow-Origin"].should eq("*")
      call_request_on_app(HTTP::Request.new("DELETE", "/api/admin/1")).status_code.should eq(401)
    end

    it "closes the connection of a handshake a filter refuses" do
      router = Kemal::Router.new
      router.before "/private" { |env| halt env, status_code: 401 }
      router.ws "/private" { }
      router.ws "/public" { }

      mount "/api", router

      headers = ws_upgrade_headers_for_origin("http://localhost")
      headers["Connection"] = "keep-alive, Upgrade"
      refused = create_ws_request_and_return_io_and_context(build_main_handler, HTTP::Request.new("GET", "/api/private", headers))[0].to_s
      refused.should start_with("HTTP/1.1 401 Unauthorized")
      refused.should contain("Connection: close")
      upgraded = create_ws_request_and_return_io_and_context(build_main_handler, HTTP::Request.new("GET", "/api/public", headers))[0].to_s
      upgraded.should start_with("HTTP/1.1 101 Switching Protocols")
      upgraded.should_not contain("Connection: close")
    end

    it "leaves a top-level route on a router's path to the top-level filters" do
      router = Kemal::Router.new
      router.before { |env| halt env, status_code: 401 }
      router.get "/x" { "secret" }

      mount "/api", router
      post "/api/x" { "public" }

      call_request_on_app(HTTP::Request.new("POST", "/api/x")).body.should eq("public")
    end
  end

  describe "router with prefix" do
    it "initializes router with prefix" do
      router = Kemal::Router.new("/v2")
      router.get "/status" do
        "v2 status"
      end

      mount "/api", router

      request = HTTP::Request.new("GET", "/api/v2/status")
      client_response = call_request_on_app(request)
      client_response.body.should eq("v2 status")
    end
  end

  describe "edge cases" do
    it "handles trailing slashes correctly" do
      router = Kemal::Router.new
      router.get "/users/" do
        "users with trailing slash"
      end

      mount "/api/", router

      request = HTTP::Request.new("GET", "/api/users/")
      client_response = call_request_on_app(request)
      client_response.body.should eq("users with trailing slash")
    end

    it "handles root path in namespace" do
      router = Kemal::Router.new

      router.namespace "/users" do
        get "" do
          "users root"
        end
      end

      mount "/api", router

      request = HTTP::Request.new("GET", "/api/users")
      client_response = call_request_on_app(request)
      client_response.body.should eq("users root")
    end

    it "returns non-string values as empty string" do
      router = Kemal::Router.new
      router.get "/number" do
        42
      end

      mount router

      request = HTTP::Request.new("GET", "/number")
      client_response = call_request_on_app(request)
      client_response.body.should eq("")
    end
  end
end
