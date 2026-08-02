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

class AllMethodsOnlyHandler < Kemal::Handler
  only ["/only"], "*"

  def call(env)
    return call_next(env) unless only_match?(env)
    env.response.print "Only"
    call_next env
  end
end

class PrefixOnlyHandler < Kemal::Handler
  only ["/admin/*"]

  def call(env)
    return call_next(env) unless only_match?(env)
    env.response.print "Only"
    call_next env
  end
end

class PrefixAllMethodsOnlyHandler < Kemal::Handler
  only ["/admin/*"], "*"

  def call(env)
    return call_next(env) unless only_match?(env)
    env.response.print "Only"
    call_next env
  end
end

class PrefixAllMethodsExcludeHandler < Kemal::Handler
  exclude ["/public/*"], "*"

  def call(env)
    return call_next(env) if exclude_match?(env)
    env.response.print "Secure"
    call_next env
  end
end

class AdminPrefixHandler < Kemal::Handler
  only ["/admin/*"], "*"

  def call(env)
    return call_next(env) unless only_match?(env)
    env.response.print "Admin"
    call_next env
  end
end

class ApiPrefixHandler < Kemal::Handler
  only ["/api/*"], "*"

  def call(env)
    return call_next(env) unless only_match?(env)
    env.response.print "Api"
    call_next env
  end
end

describe "Handler" do
  it "adds custom handler before before_*" do
    filter_middleware = Kemal::FilterHandler.new
    filter_middleware._add_route_filter("GET", "/", :before) do |env|
      env.response << " is"
    end

    filter_middleware._add_route_filter("GET", "/", :before) do |env|
      env.response << " so"
    end
    use CustomTestHandler.new

    get "/" do
      " Great"
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(200)
    client_response.body.should eq("Kemal is so Great")
  end

  it "runs specified only_routes in middleware" do
    get "/only" do
      "Get"
    end
    use OnlyHandler.new
    request = HTTP::Request.new("GET", "/only")
    client_response = call_request_on_app(request)
    client_response.body.should eq "OnlyGet"
  end

  it "doesn't run specified exclude_routes in middleware" do
    get "/" do
      "Get"
    end
    get "/exclude" do
      "Exclude"
    end
    use ExcludeHandler.new
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.body.should eq "ExcludeGet"
  end

  it "runs specified only_routes with method in middleware" do
    post "/only" do
      "Post"
    end
    get "/only" do
      "Get"
    end
    use PostOnlyHandler.new
    request = HTTP::Request.new("POST", "/only")
    client_response = call_request_on_app(request)
    client_response.body.should eq "OnlyPost"
  end

  it "doesn't run specified exclude_routes with method in middleware" do
    post "/exclude" do
      "Post"
    end
    post "/only" do
      "Post"
    end
    use PostOnlyHandler.new
    use PostExcludeHandler.new
    request = HTTP::Request.new("POST", "/only")
    client_response = call_request_on_app(request)
    client_response.body.should eq "OnlyExcludePost"
  end

  it "adds a handler at given position" do
    post_handler = PostOnlyHandler.new
    use post_handler, position: 1
    Kemal.config.setup
    Kemal.config.handlers[1].should eq post_handler
  end

  it "assigns custom handlers" do
    post_only_handler = PostOnlyHandler.new
    post_exclude_handler = PostExcludeHandler.new
    Kemal.config.handlers = [post_only_handler, post_exclude_handler]
    Kemal.config.handlers.should eq [post_only_handler, post_exclude_handler]
  end

  it "is able to use %w in macros" do
    post_only_handler = PostOnlyHandlerPercentW.new
    exclude_handler = ExcludeHandlerPercentW.new
    Kemal.config.handlers = [post_only_handler, exclude_handler]
    Kemal.config.handlers.should eq [post_only_handler, exclude_handler]
  end

  it "runs only_routes for all methods when method is *" do
    post "/only" do
      "Post"
    end
    delete "/only" do
      "Delete"
    end
    use AllMethodsOnlyHandler.new

    post_response = call_request_on_app(HTTP::Request.new("POST", "/only"))
    post_response.body.should eq "OnlyPost"

    delete_response = call_request_on_app(HTTP::Request.new("DELETE", "/only"))
    delete_response.body.should eq "OnlyDelete"
  end

  it "runs only_routes for path prefixes ending with /*" do
    get "/admin" do
      "Root"
    end
    get "/admin/users" do
      "Users"
    end
    get "/adminx" do
      "Other"
    end
    use PrefixOnlyHandler.new

    call_request_on_app(HTTP::Request.new("GET", "/admin")).body.should eq "OnlyRoot"
    call_request_on_app(HTTP::Request.new("GET", "/admin/users")).body.should eq "OnlyUsers"
    call_request_on_app(HTTP::Request.new("GET", "/adminx")).body.should eq "Other"
  end

  it "runs only_routes for path prefixes on all methods" do
    post "/admin/users" do
      "Users"
    end
    use PrefixAllMethodsOnlyHandler.new

    response = call_request_on_app(HTTP::Request.new("POST", "/admin/users"))
    response.body.should eq "OnlyUsers"
  end

  it "skips exclude_routes for path prefixes on all methods" do
    get "/public/logo.png" do
      "Asset"
    end
    post "/secret" do
      "Secret"
    end
    use PrefixAllMethodsExcludeHandler.new

    call_request_on_app(HTTP::Request.new("GET", "/public/logo.png")).body.should eq "Asset"
    call_request_on_app(HTTP::Request.new("POST", "/secret")).body.should eq "SecureSecret"
  end

  it "scopes path prefixes to the handler class" do
    get "/admin/users" do
      "Users"
    end
    get "/api/users" do
      "Users"
    end
    use AdminPrefixHandler.new
    use ApiPrefixHandler.new

    call_request_on_app(HTTP::Request.new("GET", "/admin/users")).body.should eq "AdminUsers"
    call_request_on_app(HTTP::Request.new("GET", "/api/users")).body.should eq "ApiUsers"
  end
end
