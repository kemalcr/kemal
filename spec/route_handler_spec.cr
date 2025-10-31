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
    client_response.headers.has_key?("Location").should eq(true)
  end

  it "redirects with body" do
    get "/" do |env|
      env.redirect "/login", body: "Redirecting to /login"
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(302)
    client_response.body.should eq("Redirecting to /login")
    client_response.headers.has_key?("Location").should eq(true)
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
    client_response.headers.has_key?("Location").should eq(true)
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
    client_response.headers.has_key?("Location").should eq(true)
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
  end
end
