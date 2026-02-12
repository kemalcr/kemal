require "./spec_helper"

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
      }
      request = HTTP::Request.new("GET", "/ws/room/123", headers)

      io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
      io_with_context.to_s.should contain("101 Switching Protocols")
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
