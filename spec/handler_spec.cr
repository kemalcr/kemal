require "./spec_helper"

class CustomTestHandler < Kemal::Handler
  def call(env)
    env.response << "Kemal"
    call_next env
  end
end

class OnlyHandler < Kemal::Handler
  only ["/only"]

  def call(env)
    return call_next(env) unless only_match?(env)
    env.response.print "Only"
    call_next env
  end
end

class ExcludeHandler < Kemal::Handler
  exclude ["/exclude"]

  def call(env)
    return call_next(env) if exclude_match?(env)
    env.response.print "Exclude"
    call_next env
  end
end

class PostOnlyHandler < Kemal::Handler
  only ["/only", "/route1", "/route2"], "POST"

  def call(env)
    return call_next(env) unless only_match?(env)
    env.response.print "Only"
    call_next env
  end
end

class PostExcludeHandler < Kemal::Handler
  exclude ["/exclude"], "POST"

  def call(env)
    return call_next(env) if exclude_match?(env)
    env.response.print "Exclude"
    call_next env
  end
end

class ExcludeHandlerPercentW < Kemal::Handler
  exclude %w[/exclude]

  def call(env)
    return call_next(env) if exclude_match?(env)
    env.response.print "Exclude"
    call_next env
  end
end

class PostOnlyHandlerPercentW < Kemal::Handler
  only %w[/only /route1 /route2], "POST"

  def call(env)
    return call_next(env) unless only_match?(env)
    env.response.print "Only"
    call_next env
  end
end

describe "Handler" do
  it "adds custom handler before before_*" do
    filter_middleware = Kemal::FilterHandler.new
    Kemal.application.add_filter_handler filter_middleware
    filter_middleware._add_route_filter("GET", "/", :before) do |env|
      env.response << " is"
    end

    filter_middleware._add_route_filter("GET", "/", :before) do |env|
      env.response << " so"
    end
    app = Kemal::Base.new
    app.add_filter_handler filter_middleware

    app.add_handler CustomTestHandler.new

    app.get "/" do |env|
      " Great"
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(app, request)
    client_response.status_code.should eq(200)
    client_response.body.should eq("Kemal is so Great")
  end

  it "runs specified only_routes in middleware" do
    app = Kemal::Base.new
    app.get "/only" do |env|
      "Get"
    end
    app.add_handler OnlyHandler.new
    request = HTTP::Request.new("GET", "/only")
    client_response = call_request_on_app(app, request)
    client_response.body.should eq "OnlyGet"
  end

  it "doesn't run specified exclude_routes in middleware" do
    app = Kemal::Base.new
    app.get "/" do |env|
      "Get"
    end
    app.get "/exclude" do
      "Exclude"
    end
    app.add_handler ExcludeHandler.new
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(app, request)
    client_response.body.should eq "ExcludeGet"
  end

  it "runs specified only_routes with method in middleware" do
    app = Kemal::Base.new
    app.post "/only" do
      "Post"
    end
    app.get "/only" do
      "Get"
    end
    app.add_handler PostOnlyHandler.new
    request = HTTP::Request.new("POST", "/only")
    client_response = call_request_on_app(app, request)
    client_response.body.should eq "OnlyPost"
  end

  it "doesn't run specified exclude_routes with method in middleware" do
    app = Kemal::Base.new
    app.post "/exclude" do
      "Post"
    end
    app.post "/only" do
      "Post"
    end
    app.add_handler PostOnlyHandler.new
    app.add_handler PostExcludeHandler.new
    request = HTTP::Request.new("POST", "/only")
    client_response = call_request_on_app(app, request)
    client_response.body.should eq "OnlyExcludePost"
  end

  it "adds a handler at given position" do
    post_handler = PostOnlyHandler.new
    app = Kemal::Base.new
    app.add_handler post_handler, 1
    app.setup
    app.handlers[1].should eq post_handler
  end

  it "assigns custom handlers" do
    post_only_handler = PostOnlyHandler.new
    post_exclude_handler = PostExcludeHandler.new
    app = Kemal::Base.new
    app.handlers = [post_only_handler, post_exclude_handler]
    app.handlers.should eq [post_only_handler, post_exclude_handler]
  end

  it "is able to use %w in macros" do
    post_only_handler = PostOnlyHandlerPercentW.new
    exclude_handler = ExcludeHandlerPercentW.new
    Kemal.application.handlers = [post_only_handler, exclude_handler]
    Kemal.application.handlers.should eq [post_only_handler, exclude_handler]
  end
end
