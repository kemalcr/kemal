require "./spec_helper"

# Guards the path prefix Kemal's `use "/prefix", handler` form scopes on.
class PrefixAuthHandler < Kemal::Handler
  def call(env)
    env.response.status_code = 401
    env.response.print "auth required"
  end
end

# Guards a path subtree through `only`, on every method.
class OnlyAuthHandler < Kemal::Handler
  only ["/api/*"], "*"

  def call(env)
    return call_next(env) unless only_match?(env)
    env.response.status_code = 401
    env.response.print "auth required"
  end
end

describe "Kemal::MethodValidationHandler" do
  it "refuses a method that is not an RFC 9110 token" do
    get "/admin/secret" do
      "TOP-SECRET-DATA"
    end

    response = call_request_on_app(crafted_method_request("GET/admin", "/secret"))
    response.status_code.should eq(400)
    response.body.should eq("Bad Request")
    response.headers["Content-Type"].should eq("text/plain")
  end

  it "refuses an empty method" do
    get "/" do
      "hello"
    end

    call_request_on_app(crafted_method_request("", "/")).status_code.should eq(400)
  end

  # The check rejects malformed tokens, not unfamiliar ones - what to answer a
  # `PROPFIND` with is the router's business.
  it "leaves an unfamiliar but well-formed method to the router" do
    get "/thing" do
      "get"
    end

    response = call_request_on_app(HTTP::Request.new("PROPFIND", "/thing"))
    response.status_code.should eq(405)
    response.headers["Allow"].should eq("GET, HEAD")
  end

  # The handler stands behind `Kemal::ExceptionHandler`, so the refusal is
  # rendered like every other 400 Kemal produces rather than as a response of
  # its own.
  it "is rendered by a registered error 400 handler" do
    error 400 do |env|
      env.response.content_type = "application/json"
      {error: "malformed request"}.to_json
    end

    get "/" do
      "hello"
    end

    response = call_request_on_app(crafted_method_request("GET/", "/"))
    response.status_code.should eq(400)
    response.headers["Content-Type"].should eq("application/json")
    response.body.should eq(%({"error":"malformed request"}))
  end

  # `Kemal.config.handlers=` hands the whole chain over, so an application can
  # leave this handler out of it. `Kemal::RouteHandler` asks the same question
  # again where the ambiguous key is actually built, so no route runs for such a
  # method even then.
  it "is refused by the router in a chain assembled without it" do
    get "/admin/secret" do
      "TOP-SECRET-DATA"
    end

    # Built by hand rather than through `Kemal.config.setup`, which would put the
    # handler back: the point is a chain that never had it.
    exception_handler = Kemal::ExceptionHandler.new
    exception_handler.next = Kemal::RouteHandler::INSTANCE

    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    exception_handler.call(HTTP::Server::Context.new(crafted_method_request("GET/admin", "/secret"), response))
    response.close
    io.rewind

    client_response = HTTP::Client::Response.from_io(io, decompress: false)
    client_response.status_code.should eq(400)
    client_response.body.should_not contain("TOP-SECRET-DATA")
  end

  # `Kemal::PathHandler` matches on `request.path`, so `GET/dash` + `/home` used
  # to resolve to `get "/dash/home"` with the handler behind `use "/dash"` never
  # seeing the request as one of its own (#820).
  it "cannot be used to step around a path-scoped use" do
    use "/dash", PrefixAuthHandler.new

    get "/dash/home" do
      "DASHBOARD-DATA"
    end

    call_request_on_app(HTTP::Request.new("GET", "/dash/home")).status_code.should eq(401)

    response = call_request_on_app(crafted_method_request("GET/dash", "/home"))
    response.status_code.should eq(400)
    response.body.should_not contain("DASHBOARD-DATA")
  end

  # `Kemal::Handler#only_match?` matches on `request.path` too, and a rule on
  # `"*"` covers the method the desynced request arrived with.
  it "cannot be used to step around an only rule" do
    use OnlyAuthHandler.new

    delete "/api/users/:id" do
      "DELETED"
    end

    call_request_on_app(HTTP::Request.new("DELETE", "/api/users/42")).status_code.should eq(401)

    response = call_request_on_app(crafted_method_request("DELETE/api", "/users/42"))
    response.status_code.should eq(400)
    response.body.should_not contain("DELETED")
  end
end
