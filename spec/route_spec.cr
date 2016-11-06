require "./spec_helper"

class OnlyHandler < HTTP::Handler
  def call(env)
    only_routes env, ["/only"]
    env.response.print "Only"
    call_next env
  end

  def write(message)
  end
end

class ExcludeHandler < HTTP::Handler
  def call(env)
    exclude_routes env, ["/exclude"]
    env.response.print "Exclude"
    call_next env
  end

  def write(message)
  end
end

describe "Route" do
  describe "match?" do
    it "matches the correct route" do
      get "/route1" do |env|
        "Route 1"
      end
      get "/route2" do |env|
        "Route 2"
      end
      request = HTTP::Request.new("GET", "/route2")
      client_response = call_request_on_app(request)
      client_response.body.should eq("Route 2")
    end

    it "doesn't allow a route declaration start without /" do
      expect_raises Kemal::Exceptions::InvalidPathStartException, "Route declaration get \"route\" needs to start with '/', should be get \"/route\"" do
        get "route" do |env|
          "Route 1"
        end
      end
    end

    it "runs specified only_routes in middleware" do
      get "/" do
        "Not"
      end
      add_handler OnlyHandler.new
      request = HTTP::Request.new("GET", "/only")
      client_response = call_request_on_app(request)
      client_response.body.should eq "Only"
    end

    it "doesn't run specified exclude_routes in middleware" do
      get "/exclude" do
        "Not"
      end
      add_handler ExcludeHandler.new
      request = HTTP::Request.new("GET", "/")
      client_response = call_request_on_app(request)
      client_response.body.should eq "Exclude"
    end
  end
end
