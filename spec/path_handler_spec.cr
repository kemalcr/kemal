require "./spec_helper"

# Test middleware that sets a header
class TestHeaderHandler < Kemal::Handler
  def initialize(@header_name : String, @header_value : String)
  end

  def call(env)
    env.response.headers[@header_name] = @header_value
    call_next(env)
  end
end

# Test middleware that blocks requests
class BlockingHandler < Kemal::Handler
  def call(env)
    env.response.status_code = 401
    env.response.print "Blocked"
    # Don't call_next - stop the chain
  end
end

# Test middleware that sets context value
class ContextSetterHandler < Kemal::Handler
  def initialize(@key : String, @value : String)
  end

  def call(env)
    env.set @key, @value
    call_next(env)
  end
end

describe "PathHandler" do
  describe "use (global)" do
    it "adds middleware that runs for all requests" do
      use TestHeaderHandler.new("X-Global", "yes")

      get "/test1" do
        "test1"
      end

      get "/other/path" do
        "other"
      end

      request1 = HTTP::Request.new("GET", "/test1")
      response1 = call_request_on_app(request1)
      response1.headers["X-Global"].should eq("yes")

      request2 = HTTP::Request.new("GET", "/other/path")
      response2 = call_request_on_app(request2)
      response2.headers["X-Global"].should eq("yes")
    end
  end

  describe "use with path prefix" do
    it "runs middleware only for matching path prefix" do
      use "/api", TestHeaderHandler.new("X-API", "true")

      get "/api/users" do
        "api users"
      end

      get "/web/home" do
        "web home"
      end

      # Should have header for /api/*
      api_request = HTTP::Request.new("GET", "/api/users")
      api_response = call_request_on_app(api_request)
      api_response.headers["X-API"]?.should eq("true")
      api_response.body.should eq("api users")

      # Should NOT have header for /web/*
      web_request = HTTP::Request.new("GET", "/web/home")
      web_response = call_request_on_app(web_request)
      web_response.headers["X-API"]?.should be_nil
      web_response.body.should eq("web home")
    end

    it "matches exact path" do
      use "/api", TestHeaderHandler.new("X-Exact", "matched")

      get "/api" do
        "api root"
      end

      request = HTTP::Request.new("GET", "/api")
      response = call_request_on_app(request)
      response.headers["X-Exact"]?.should eq("matched")
    end

    it "matches nested paths" do
      use "/api", TestHeaderHandler.new("X-Nested", "yes")

      get "/api/v1/users/123/posts" do
        "nested"
      end

      request = HTTP::Request.new("GET", "/api/v1/users/123/posts")
      response = call_request_on_app(request)
      response.headers["X-Nested"]?.should eq("yes")
    end

    it "does not match similar prefixes" do
      use "/api", TestHeaderHandler.new("X-API-Only", "true")

      get "/apiv2/users" do
        "apiv2"
      end

      get "/api-old/users" do
        "api-old"
      end

      # /apiv2 should NOT match /api
      request1 = HTTP::Request.new("GET", "/apiv2/users")
      response1 = call_request_on_app(request1)
      response1.headers["X-API-Only"]?.should be_nil

      # /api-old should NOT match /api
      request2 = HTTP::Request.new("GET", "/api-old/users")
      response2 = call_request_on_app(request2)
      response2.headers["X-API-Only"]?.should be_nil
    end

    it "does not match root when prefix is set" do
      use "/admin", TestHeaderHandler.new("X-Admin", "true")

      get "/" do
        "home"
      end

      request = HTTP::Request.new("GET", "/")
      response = call_request_on_app(request)
      response.headers["X-Admin"]?.should be_nil
    end
  end

  describe "multiple middlewares" do
    it "runs multiple middlewares in order" do
      use "/api", TestHeaderHandler.new("X-First", "1")
      use "/api", TestHeaderHandler.new("X-Second", "2")

      get "/api/test" do
        "test"
      end

      request = HTTP::Request.new("GET", "/api/test")
      response = call_request_on_app(request)
      response.headers["X-First"]?.should eq("1")
      response.headers["X-Second"]?.should eq("2")
    end

    it "supports array of middlewares" do
      use "/multi", [
        TestHeaderHandler.new("X-A", "a"),
        TestHeaderHandler.new("X-B", "b"),
        TestHeaderHandler.new("X-C", "c"),
      ]

      get "/multi/test" do
        "multi"
      end

      request = HTTP::Request.new("GET", "/multi/test")
      response = call_request_on_app(request)
      response.headers["X-A"]?.should eq("a")
      response.headers["X-B"]?.should eq("b")
      response.headers["X-C"]?.should eq("c")
    end

    it "different paths have different middlewares" do
      use "/api", TestHeaderHandler.new("X-API", "api")
      use "/admin", TestHeaderHandler.new("X-Admin", "admin")

      get "/api/data" do
        "api data"
      end

      get "/admin/dashboard" do
        "admin dashboard"
      end

      api_request = HTTP::Request.new("GET", "/api/data")
      api_response = call_request_on_app(api_request)
      api_response.headers["X-API"]?.should eq("api")
      api_response.headers["X-Admin"]?.should be_nil

      admin_request = HTTP::Request.new("GET", "/admin/dashboard")
      admin_response = call_request_on_app(admin_request)
      admin_response.headers["X-Admin"]?.should eq("admin")
      admin_response.headers["X-API"]?.should be_nil
    end
  end

  describe "middleware can block requests" do
    it "middleware can stop the chain" do
      use "/protected", BlockingHandler.new

      get "/protected/secret" do
        "secret data"
      end

      get "/public" do
        "public data"
      end

      # Protected route should be blocked
      protected_request = HTTP::Request.new("GET", "/protected/secret")
      protected_response = call_request_on_app(protected_request)
      protected_response.status_code.should eq(401)
      protected_response.body.should eq("Blocked")

      # Public route should work
      public_request = HTTP::Request.new("GET", "/public")
      public_response = call_request_on_app(public_request)
      public_response.status_code.should eq(200)
      public_response.body.should eq("public data")
    end
  end

  describe "middleware with context" do
    it "middleware can set context values" do
      use "/ctx", ContextSetterHandler.new("middleware_ran", "yes")

      get "/ctx/check" do |env|
        env.get("middleware_ran").to_s
      end

      request = HTTP::Request.new("GET", "/ctx/check")
      response = call_request_on_app(request)
      response.body.should eq("yes")
    end
  end

  describe "PathHandler" do
    describe "#matches_prefix?" do
      it "root prefix matches all" do
        get "/anything" do
          "ok"
        end

        use "/", TestHeaderHandler.new("X-Root", "all")

        request = HTTP::Request.new("GET", "/anything")
        response = call_request_on_app(request)
        response.headers["X-Root"]?.should eq("all")
      end

      it "empty prefix matches all" do
        use "", TestHeaderHandler.new("X-Empty", "all")

        get "/some/path" do
          "ok"
        end

        request = HTTP::Request.new("GET", "/some/path")
        response = call_request_on_app(request)
        response.headers["X-Empty"]?.should eq("all")
      end
    end
  end
end
