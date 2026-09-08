require "./spec_helper"

describe "Kemal::RouteHandler" do
  it "routes" do
    get "/" do
      "hello"
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.body.should eq("hello")
  end

  it "routes with long response body" do
    long_response_body = "string" * 10_000

    get "/" do
      long_response_body
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.body.should eq(long_response_body)
  end

  it "routes should only return strings" do
    get "/" do
      100
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.body.should eq("")
  end

  it "routes request with query string" do
    get "/" do |env|
      "hello #{env.params.query["message"]}"
    end
    request = HTTP::Request.new("GET", "/?message=world")
    client_response = call_request_on_app(request)
    client_response.body.should eq("hello world")
  end

  it "routes request with multiple query strings" do
    get "/" do |env|
      "hello #{env.params.query["message"]} time #{env.params.query["time"]}"
    end
    request = HTTP::Request.new("GET", "/?message=world&time=now")
    client_response = call_request_on_app(request)
    client_response.body.should eq("hello world time now")
  end

  it "route parameter has more precedence than query string arguments" do
    get "/:message" do |env|
      "hello #{env.params.url["message"]}"
    end
    request = HTTP::Request.new("GET", "/world?message=coco")
    client_response = call_request_on_app(request)
    client_response.body.should eq("hello world")
  end

  it "parses simple JSON body" do
    post "/" do |env|
      name = env.params.json["name"]
      age = env.params.json["age"]
      "Hello #{name} Age #{age}"
    end

    json_payload = {"name": "Serdar", "age": 26}
    request = HTTP::Request.new(
      "POST",
      "/",
      body: json_payload.to_json,
      headers: HTTP::Headers{"Content-Type" => "application/json"},
    )
    client_response = call_request_on_app(request)
    client_response.body.should eq("Hello Serdar Age 26")
  end

  it "parses JSON with string array" do
    post "/" do |env|
      skills = env.params.json["skills"].as(Array)
      "Skills #{skills.each.join(',')}"
    end

    json_payload = {"skills": ["ruby", "crystal"]}
    request = HTTP::Request.new(
      "POST",
      "/",
      body: json_payload.to_json,
      headers: HTTP::Headers{"Content-Type" => "application/json"},
    )
    client_response = call_request_on_app(request)
    client_response.body.should eq("Skills ruby,crystal")
  end

  it "parses JSON with json object array" do
    post "/" do |env|
      skills = env.params.json["skills"].as(Array)
      skills_from_languages = skills.map do |skill|
        skill["language"]
      end
      "Skills #{skills_from_languages.each.join(',')}"
    end

    json_payload = {"skills": [{"language": "ruby"}, {"language": "crystal"}]}
    request = HTTP::Request.new(
      "POST",
      "/",
      body: json_payload.to_json,
      headers: HTTP::Headers{"Content-Type" => "application/json"},
    )

    client_response = call_request_on_app(request)
    client_response.body.should eq("Skills ruby,crystal")
  end

  it "routes QUERY request with url-encoded body params" do
    query "/search" do |env|
      "Searching for #{env.params.body["q"]}"
    end
    request = HTTP::Request.new(
      "QUERY",
      "/search",
      body: "q=kemal",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
    )
    client_response = call_request_on_app(request)
    client_response.body.should eq("Searching for kemal")
  end

  it "routes QUERY request with JSON body" do
    query "/search" do |env|
      "Searching for #{env.params.json["q"]}"
    end
    request = HTTP::Request.new(
      "QUERY",
      "/search",
      body: {"q": "kemal"}.to_json,
      headers: HTTP::Headers{"Content-Type" => "application/json"},
    )
    client_response = call_request_on_app(request)
    client_response.body.should eq("Searching for kemal")
  end

  it "keeps query string and body params separate for QUERY requests" do
    query "/search" do |env|
      "page #{env.params.query["page"]} q #{env.params.body["q"]}"
    end
    request = HTTP::Request.new(
      "QUERY",
      "/search?page=2",
      body: "q=kemal",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
    )
    client_response = call_request_on_app(request)
    client_response.body.should eq("page 2 q kemal")
  end

  it "does not serve a QUERY request from a GET route" do
    error 404 do
      "not found"
    end
    get "/only_get" do
      "get"
    end
    Kemal::RouteHandler::INSTANCE.lookup_route("QUERY", "/only_get").found?.should be_false
    request = HTTP::Request.new("QUERY", "/only_get")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(405)
    client_response.headers["Allow"].should eq("GET, HEAD")
  end

  it "does not serve GET or HEAD requests from a QUERY route" do
    error 404 do
      "not found"
    end
    query "/only_query" do
      "query"
    end
    Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/only_query").found?.should be_false
    Kemal::RouteHandler::INSTANCE.lookup_route("HEAD", "/only_query").found?.should be_false
    call_request_on_app(HTTP::Request.new("GET", "/only_query")).status_code.should eq(405)
    call_request_on_app(HTTP::Request.new("HEAD", "/only_query")).status_code.should eq(405)
  end

  context "QUERY Content-Type enforcement (RFC 10008)" do
    it "rejects a QUERY request that has a body but no Content-Type with 400" do
      query "/search" do
        "should not run"
      end
      request = HTTP::Request.new("QUERY", "/search", body: "q=kemal")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(400)
      client_response.body.should eq("QUERY request with a body requires a Content-Type header")
    end

    it "rejects a chunked QUERY request without Content-Type with 400" do
      query "/search" do
        "should not run"
      end
      request = HTTP::Request.new(
        "QUERY",
        "/search",
        headers: HTTP::Headers{"Transfer-Encoding" => "chunked"},
        body: IO::Memory.new("q=kemal"),
      )
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(400)
    end

    it "rejects a chunked QUERY request without Content-Type even when Content-Length is 0" do
      query "/search" do
        "should not run"
      end
      request = HTTP::Request.new(
        "QUERY",
        "/search",
        headers: HTTP::Headers{"Content-Length" => "0", "Transfer-Encoding" => "chunked"},
        body: IO::Memory.new("q=kemal"),
      )
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(400)
    end

    it "rejects a QUERY request with duplicate Content-Length headers and no Content-Type" do
      query "/search" do
        "should not run"
      end
      headers = HTTP::Headers.new
      headers.add("Content-Length", "7")
      headers.add("Content-Length", "7")
      request = HTTP::Request.new("QUERY", "/search", headers: headers, body: IO::Memory.new("q=kemal"))
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(400)
    end

    it "rejects a QUERY request with an empty Content-Type value" do
      query "/search" do
        "should not run"
      end
      request = HTTP::Request.new(
        "QUERY",
        "/search",
        body: "q=kemal",
        headers: HTTP::Headers{"Content-Type" => ""},
      )
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(400)
    end

    it "lets a before_query filter halt before Content-Type validation" do
      before_query "/search" do |env|
        halt env, status_code: 401, response: "unauthorized"
      end
      query "/search" do
        "should not run"
      end
      request = HTTP::Request.new("QUERY", "/search", body: "q=kemal")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(401)
      client_response.body.should eq("unauthorized")
    end

    it "renders a custom error 400 handler for invalid QUERY requests" do
      error 400 do
        "custom bad request"
      end
      query "/search" do
        "should not run"
      end
      request = HTTP::Request.new("QUERY", "/search", body: "q=kemal")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(400)
      client_response.body.should eq("custom bad request")
    end

    it "allows a QUERY request without a body and without Content-Type" do
      query "/search" do
        "empty query"
      end
      request = HTTP::Request.new("QUERY", "/search")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.body.should eq("empty query")
    end

    it "allows a QUERY request with a body and a Content-Type" do
      query "/search" do |env|
        "q is #{env.params.body["q"]}"
      end
      request = HTTP::Request.new(
        "QUERY",
        "/search",
        body: "q=kemal",
        headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      )
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.body.should eq("q is kemal")
    end
  end

  it "can process HTTP HEAD requests for defined GET routes" do
    get "/" do
      "Hello World from GET"
    end
    request = HTTP::Request.new("HEAD", "/")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(200)
  end

  it "redirects user to provided url" do
    get "/" do |env|
      env.redirect "/login"
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(302)
    client_response.body.should eq("")
    client_response.headers.has_key?("Location").should be_true
  end

  it "redirects with body" do
    get "/" do |env|
      env.redirect "/login", body: "Redirecting to /login"
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(302)
    client_response.body.should eq("Redirecting to /login")
    client_response.headers.has_key?("Location").should be_true
  end

  it "redirects and closes response in before filter" do
    filter_handler = Kemal::FilterHandler.new
    filter_handler._add_route_filter("GET", "/", :before) do |env|
      env.redirect "/login"
    end
    Kemal.config.add_filter_handler(filter_handler)

    get "/" do
      "home page"
    end

    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(302)
    client_response.body.should eq("")
    client_response.headers.has_key?("Location").should be_true
  end

  it "redirects in before filter without closing response" do
    filter_handler = Kemal::FilterHandler.new
    filter_handler._add_route_filter("GET", "/", :before) do |env|
      env.redirect "/login", close: false
    end
    Kemal.config.add_filter_handler(filter_handler)

    get "/" do
      "home page"
    end

    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(302)
    client_response.body.should eq("home page")
    client_response.headers.has_key?("Location").should be_true
  end

  it "replaces the Location of an earlier redirect instead of adding a second one" do
    # A filter redirected without closing; the route then redirects elsewhere. The
    # client must see one `Location`, the last one - not two to choose from.
    filter_handler = Kemal::FilterHandler.new
    filter_handler._add_route_filter("GET", "/", :before) do |env|
      env.redirect "/login", close: false
    end
    Kemal.config.add_filter_handler(filter_handler)

    get "/" do |env|
      env.redirect "/dashboard"
    end

    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(302)
    client_response.headers.get("Location").should eq(["/dashboard"])
  end

  context "LRU cache" do
    it "evicts least recently used entries instead of clearing entirely" do
      # Use a small capacity to make the test fast and deterministic
      small_capacity = 8
      # Replace the cache instance with a smaller-capacity LRU for this test
      Kemal::RouteHandler::INSTANCE.cached_routes = Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(small_capacity)

      # Define more routes than capacity
      0.upto(15) do |i|
        get "/lru_eviction_#{i}" do
          "ok"
        end
      end

      # Access the first `small_capacity` routes to fill the cache
      0.upto(small_capacity - 1) do |i|
        Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/lru_eviction_#{i}")
      end

      Kemal::RouteHandler::INSTANCE.cached_routes.size.should eq small_capacity

      # Access some new routes to trigger eviction
      small_capacity.upto(small_capacity + 3) do |i|
        Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/lru_eviction_#{i}")
      end

      # Cache should still be capped at capacity
      Kemal::RouteHandler::INSTANCE.cached_routes.size.should eq small_capacity
    end

    it "retains recently used keys and evicts the least recently used" do
      small_capacity = 4
      Kemal::RouteHandler::INSTANCE.cached_routes = Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(small_capacity)

      0.upto(5) do |i|
        get "/lru_recency_#{i}" do
          "ok"
        end
      end

      # Fill cache with 0..3
      0.upto(3) do |i|
        Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/lru_recency_#{i}")
      end

      # Touch 0 and 1 to make them most recent
      [0, 1].each do |i|
        Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/lru_recency_#{i}")
      end

      # Insert 4 -> should evict least recent among {2,3}
      Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/lru_recency_4")

      # Insert 5 -> should evict the other of {2,3}
      Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/lru_recency_5")

      # Now 0 and 1 must still resolve from cache, and size is capped
      Kemal::RouteHandler::INSTANCE.cached_routes.size.should eq small_capacity

      # A fresh lookup for 0 and 1 should be cache hits and not raise
      Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/lru_recency_0").found?.should be_true
      Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/lru_recency_1").found?.should be_true
    end

    it "caches HEAD fallback GET lookups without growing beyond 1 for same path" do
      cap = 16
      Kemal::RouteHandler::INSTANCE.cached_routes = Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(cap)

      get "/head_fallback" do
        "ok"
      end

      # First HEAD should fallback to GET and cache one entry keyed by HEAD+path
      Kemal::RouteHandler::INSTANCE.lookup_route("HEAD", "/head_fallback").found?.should be_true
      Kemal::RouteHandler::INSTANCE.cached_routes.size.should eq 1

      # Second HEAD lookup should be a cache hit; size must remain 1
      Kemal::RouteHandler::INSTANCE.lookup_route("HEAD", "/head_fallback").found?.should be_true
      Kemal::RouteHandler::INSTANCE.cached_routes.size.should eq 1
    end

    it "caches QUERY and GET routes on the same path separately" do
      Kemal::RouteHandler::INSTANCE.cached_routes = Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(16)

      get "/dual" do
        "get"
      end
      query "/dual" do
        "query"
      end

      Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/dual").found?.should be_true
      Kemal::RouteHandler::INSTANCE.lookup_route("QUERY", "/dual").found?.should be_true
      Kemal::RouteHandler::INSTANCE.cached_routes.size.should eq 2

      # Cached lookups must keep resolving to their own method's handler
      Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/dual").payload.method.should eq "GET"
      Kemal::RouteHandler::INSTANCE.lookup_route("QUERY", "/dual").payload.method.should eq "QUERY"
    end

    it "keeps size capped under heavy churn with large capacity" do
      large_capacity = 4096
      Kemal::RouteHandler::INSTANCE.cached_routes = Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(large_capacity)

      0.upto(12000) do |i|
        get "/lru_heavy_#{i}" do
          "ok"
        end
      end

      # Fill and churn beyond capacity
      0.upto(11999) do |i|
        Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/lru_heavy_#{i}")
      end

      Kemal::RouteHandler::INSTANCE.cached_routes.size.should eq large_capacity

      # Additional churn should not increase size
      12000.upto(14000) do |i|
        get "/lru_heavy_more_#{i}" do
          "ok"
        end
        Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/lru_heavy_more_#{i}")
      end

      Kemal::RouteHandler::INSTANCE.cached_routes.size.should eq large_capacity
    end

    it "handles concurrent lookups safely" do
      Kemal::RouteHandler::INSTANCE.cached_routes = Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(256)

      get "/concurrent" do
        "ok"
      end

      channel = Channel(Nil).new
      fiber_count = 100
      fiber_count.times do
        spawn do
          Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/concurrent").found?.should be_true
          channel.send(nil)
        end
      end
      fiber_count.times { channel.receive }

      Kemal::RouteHandler::INSTANCE.cached_routes.size.should eq 1
    end

    it "invalidates a cached HEAD -> GET fallback when a HEAD route is added later" do
      get "/late" do
        "getbody"
      end

      call_request_on_app(HTTP::Request.new("HEAD", "/late"))

      Kemal::RouteHandler::INSTANCE.add_route("HEAD", "/late") { "headroute" }

      response = call_request_on_app(HTTP::Request.new("HEAD", "/late"))
      response.headers["Content-Length"].should eq("9")
    end
  end
  context "405 Method Not Allowed (RFC 9110 §15.5.6)" do
    it "answers a request whose path is routed for another method with 405" do
      get "/only_get" do
        "get"
      end

      response = call_request_on_app(HTTP::Request.new("POST", "/only_get"))
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET, HEAD")
      response.body.should eq("Method Not Allowed")
      # `Kemal::InitHandler` presets `Content-Type: text/html` on every
      # response, so the plain-text default body inherits it - the same as the
      # framework defaults for 400 and 413.
      response.headers["Content-Type"].should eq("text/html")
    end

    it "answers PUT and OPTIONS on a GET only path with 405" do
      get "/only_get" do
        "get"
      end

      %w[PUT OPTIONS DELETE PATCH].each do |method|
        response = call_request_on_app(HTTP::Request.new(method, "/only_get"))
        response.status_code.should eq(405)
        response.headers["Allow"].should eq("GET, HEAD")
      end
    end

    it "lists every method registered for the path in Allow" do
      get "/resource" do
        "get"
      end
      post "/resource" do
        "post"
      end
      delete "/resource" do
        "delete"
      end
      query "/resource" do
        "query"
      end

      response = call_request_on_app(HTTP::Request.new("PUT", "/resource"))
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET, HEAD, POST, DELETE, QUERY")
    end

    it "omits HEAD from Allow when the path has no GET route" do
      post "/only_post" do
        "post"
      end

      response = call_request_on_app(HTTP::Request.new("GET", "/only_post"))
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("POST")
    end

    it "advertises a HEAD route registered on its own" do
      Kemal::RouteHandler::INSTANCE.add_route("HEAD", "/head_only") { "" }

      response = call_request_on_app(HTTP::Request.new("POST", "/head_only"))
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("HEAD")
    end

    it "matches path parameters when collecting the allowed methods" do
      get "/users/:id" do |env|
        env.params.url["id"]
      end

      response = call_request_on_app(HTTP::Request.new("DELETE", "/users/42"))
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET, HEAD")
    end

    it "runs a custom error 405 handler and still sends Allow" do
      error 405 do |env|
        "no #{env.request.method} here"
      end
      get "/only_get" do
        "get"
      end

      response = call_request_on_app(HTTP::Request.new("POST", "/only_get"))
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET, HEAD")
      response.body.should eq("no POST here")
    end

    it "runs before_all filters for a custom error 405 handler" do
      Kemal::FilterHandler::INSTANCE._add_route_filter("ALL", "*", :before) do |env|
        env.set "filtered", "yes"
      end
      error 405 do |env|
        env.get?("filtered").to_s
      end
      get "/only_get" do
        "get"
      end

      response = call_request_on_app(HTTP::Request.new("POST", "/only_get"))
      response.status_code.should eq(405)
      response.body.should eq("yes")
    end

    it "still answers 404 for a path that is not routed at all" do
      error 404 do
        "not found"
      end
      get "/only_get" do
        "get"
      end

      response = call_request_on_app(HTTP::Request.new("POST", "/nowhere"))
      response.status_code.should eq(404)
      response.headers["Allow"]?.should be_nil
      response.body.should eq("not found")
    end

    # `GET` is what a WebSocket path serves, so a `GET` that missed cannot be a
    # 405 - it is a handshake without the `Upgrade` header. Answering
    # "405, Allow: GET" to a `GET` would be nonsense, so it stays a 404.
    #
    # `426 Upgrade Required` (RFC 9110 §15.5.22) was considered and rejected: a
    # plain `GET` here is a client bug, and 404 vs 426 does not change what the
    # client has to do.
    it "leaves a path served only by a WebSocket route as a 404" do
      error 404 do
        "not found"
      end
      ws "/chat" do |socket|
        socket.send("hello")
      end

      response = call_request_on_app(HTTP::Request.new("GET", "/chat"))
      response.status_code.should eq(404)
      response.headers["Allow"]?.should be_nil
    end

    it "answers a non-GET request to a WebSocket only path with 405" do
      ws "/chat" do |socket|
        socket.send("hello")
      end

      response = call_request_on_app(HTTP::Request.new("POST", "/chat"))
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET")
    end

    # The handshake is the only thing served on a WebSocket path, so `HEAD` is
    # not offered there the way it is for a `GET` route.
    it "does not advertise HEAD for a WebSocket only path" do
      ws "/chat" do |socket|
        socket.send("hello")
      end

      response = call_request_on_app(HTTP::Request.new("HEAD", "/chat"))
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET")
    end

    it "matches path parameters when probing WebSocket routes" do
      ws "/chat/:room" do |socket|
        socket.send("hello")
      end

      response = call_request_on_app(HTTP::Request.new("DELETE", "/chat/general"))
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET")
    end

    it "advertises the WebSocket handshake alongside the HTTP methods on the path" do
      ws "/chat" do |socket|
        socket.send("hello")
      end
      post "/chat" do
        "post"
      end

      response = call_request_on_app(HTTP::Request.new("PUT", "/chat"))
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET, POST")
    end

    it "leaves a plain GET on a path with a WebSocket and an HTTP route as a 404" do
      error 404 do
        "not found"
      end
      ws "/chat" do |socket|
        socket.send("hello")
      end
      post "/chat" do
        "post"
      end

      response = call_request_on_app(HTTP::Request.new("GET", "/chat"))
      response.status_code.should eq(404)
      response.headers["Allow"]?.should be_nil
      response.body.should eq("not found")
    end

    it "still upgrades a WebSocket handshake on a path that also serves HTTP" do
      ws "/chat" do |socket|
        socket.send("hello")
      end
      post "/chat" do
        "post"
      end

      headers = HTTP::Headers{
        "Upgrade"               => "websocket",
        "Connection"            => "Upgrade",
        "Sec-WebSocket-Key"     => "dGhlIHNhbXBsZSBub25jZQ==",
        "Sec-WebSocket-Version" => "13",
        "Host"                  => "localhost",
        "Origin"                => "http://localhost",
      }
      request = HTTP::Request.new("GET", "/chat", headers)
      io, _ = create_ws_request_and_return_io_and_context(build_main_handler, request)
      io.to_s.should contain("101 Switching Protocols")
    end

    it "does not put the probed methods into the route cache" do
      get "/only_get" do
        "get"
      end

      call_request_on_app(HTTP::Request.new("POST", "/only_get")).status_code.should eq(405)
      Kemal::RouteHandler::INSTANCE.cached_routes.size.should eq(0)
    end

    it "does not send an empty Allow header when the allowed list is empty" do
      get "/boom" do |env|
        raise Kemal::Exceptions::MethodNotAllowed.new(env, [] of String)
      end

      response = call_request_on_app(HTTP::Request.new("GET", "/boom"))
      response.status_code.should eq(405)
      response.headers["Allow"]?.should be_nil
    end

    it "leaves a request a filter already answered alone" do
      error 405 do
        "405"
      end
      Kemal::FilterHandler::INSTANCE._add_route_filter("ALL", "*", :before) do |env|
        halt env, status_code: 401, response: "Unauthorized"
      end
      get "/guarded" do
        "get"
      end

      response = call_request_on_app(HTTP::Request.new("POST", "/guarded"))
      response.status_code.should eq(401)
      response.headers["Allow"]?.should be_nil
    end

    describe "#allowed_methods" do
      it "sees routes in a tree assigned wholesale" do
        tree = Radix::Tree(Kemal::Route).new
        tree.add("/GET/preloaded", Kemal::Route.new("GET", "/preloaded") { "p" })
        Kemal::RouteHandler::INSTANCE.routes = tree

        Kemal::RouteHandler::INSTANCE.allowed_methods("/preloaded").should eq(["GET", "HEAD"])
      end

      # The verb index is fed by `add_route` and rebuilt by `routes=`. Pushing a
      # route through the `routes` getter skips both, so the path reports no
      # allowed methods and answers 404 - the pre-405 behavior - rather than an
      # `Allow` header that is missing a verb the app really serves.
      it "degrades to 404 for a route pushed straight through the getter" do
        Kemal::RouteHandler::INSTANCE.routes.add("/PUT/direct", Kemal::Route.new("PUT", "/direct") { "d" })

        Kemal::RouteHandler::INSTANCE.allowed_methods("/direct").should be_empty
        call_request_on_app(HTTP::Request.new("PUT", "/direct")).body.should eq("d")
      end

      it "returns the methods routed for a path" do
        get "/thing" do
          "get"
        end
        patch "/thing" do
          "patch"
        end

        Kemal::RouteHandler::INSTANCE.allowed_methods("/thing").should eq(["GET", "HEAD", "PATCH"])
      end

      it "returns an empty array for an unrouted path" do
        get "/thing" do
          "get"
        end

        Kemal::RouteHandler::INSTANCE.allowed_methods("/other").should be_empty
      end

      # The verb index only tracks HTTP routes, so a WebSocket-only app leaves
      # it empty. The probe has to sit outside that shortcut or such an app
      # reports nothing at all.
      it "reports GET for a WebSocket route in an app with no HTTP routes" do
        ws "/chat" do |socket|
          socket.send("hello")
        end

        Kemal::RouteHandler::INSTANCE.allowed_methods("/chat").should eq(["GET"])
      end

      it "reports GET once for a path carrying both a WebSocket and a GET route" do
        ws "/chat" do |socket|
          socket.send("hello")
        end
        get "/chat" do
          "get"
        end

        Kemal::RouteHandler::INSTANCE.allowed_methods("/chat").should eq(["GET", "HEAD"])
      end
    end
  end
end
