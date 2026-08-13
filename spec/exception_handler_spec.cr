require "./spec_helper"

describe "Kemal::ExceptionHandler" do
  it "renders 404 on route not found" do
    get "/" do
      "Hello"
    end

    request = HTTP::Request.new("GET", "/asd")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 404
  end

  it "renders custom error" do
    error 403 do
      "403 error"
    end
    get "/" do |env|
      env.response.status_code = 403
    end
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 403
    response.headers["Content-Type"].should eq "text/html"
    response.body.should eq "403 error"
  end

  it "renders custom 500 error" do
    error 500 do
      "Something happened"
    end
    get "/" do |env|
      env.response.status_code = 500
    end
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.headers["Content-Type"].should eq "text/html"
    response.body.should eq "Something happened"
  end

  it "renders custom error for a crystal exception" do
    error RuntimeError do
      "A RuntimeError has occurred"
    end

    get "/" do
      raise RuntimeError.new
    end

    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.headers["Content-Type"].should eq "text/html"
    response.body.should eq "A RuntimeError has occurred"
  end

  it "renders custom error for a custom exception" do
    error CustomExceptionType do
      "A custom exception of CustomExceptionType has occurred"
    end

    get "/" do
      raise CustomExceptionType.new
    end

    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.headers["Content-Type"].should eq "text/html"
    response.body.should eq "A custom exception of CustomExceptionType has occurred"
  end

  it "renders custom error for a custom exception with a specific HTTP status code" do
    error CustomExceptionType do |env|
      env.response.status_code = 503
      "A custom exception of CustomExceptionType has occurred"
    end

    get "/" do
      raise CustomExceptionType.new
    end

    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 503
    response.headers["Content-Type"].should eq "text/html"
    response.body.should eq "A custom exception of CustomExceptionType has occurred"
  end

  it "renders custom error for a child of a custom exception" do
    error CustomExceptionType do |_, error|
      "A custom exception of #{error.class} has occurred"
    end

    get "/" do
      raise ChildCustomExceptionType.new
    end

    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.headers["Content-Type"].should eq "text/html"
    response.body.should eq "A custom exception of ChildCustomExceptionType has occurred"
  end

  it "overrides the content type for filters" do
    before_get do |env|
      env.response.content_type = "application/json"
    end
    error 500 do |_, err|
      err.message
    end
    get "/" do |env|
      env.response.status_code = 500
    end
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.headers["Content-Type"].should eq "text/html"
    response.body.should eq "Rendered error with 500"
  end

  it "keeps the specified error Content-Type" do
    error 500 do
      "Something happened"
    end
    get "/" do |env|
      env.response.content_type = "application/json"
      env.response.status_code = 500
    end
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.headers["Content-Type"].should eq "application/json"
    response.body.should eq "Something happened"
  end

  it "renders custom error with env and error" do
    error 500 do |_, err|
      err.message
    end
    get "/" do |env|
      env.response.content_type = "application/json"
      env.response.status_code = 500
    end
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.headers["Content-Type"].should eq "application/json"
    response.body.should eq "Rendered error with 500"
  end

  it "does not do anything on a closed io" do
    get "/" do |env|
      halt env, status_code: 404
    end

    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq 404
  end

  it "renders payload too large with 413 from the exception" do
    error 413 do
      "payload too large"
    end

    get "/" do
      raise Kemal::Exceptions::PayloadTooLarge.new
    end

    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 413
    response.headers["Content-Type"].should eq "text/html"
    response.body.should eq "payload too large"
  end

  it "renders payload too large with 413 without a custom handler" do
    get "/" do
      raise Kemal::Exceptions::PayloadTooLarge.new
    end

    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 413
    response.headers["Content-Type"].should eq "text/plain"
    response.body.should eq "Payload Too Large"
  end

  it "escapes the exception message on the development error page" do
    get "/user-lookup" do |env|
      raise "User '#{env.params.query["name"]}' not found"
    end

    request = HTTP::Request.new("GET", "/user-lookup?name=%3C/title%3E%3Cscript%3Ealert(1)%3C/script%3E")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.body.should_not contain "<script>alert(1)</script>"
    response.body.should contain "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  it "escapes the request path on the development error page" do
    get "/u/*path" do
      raise "boom"
    end

    request = HTTP::Request.new("GET", "/u/<img/src=x/onerror=alert(1)>")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.body.should_not contain "<img/src=x/onerror=alert(1)>"
    response.body.should contain "&lt;img/src=x/onerror=alert(1)&gt;"
  end

  it "leaves ordinary exception messages readable on the development error page" do
    get "/" do
      raise %(User 'bob' not found in "users" & sessions)
    end

    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.body.should contain %(- User 'bob' not found in "users" & sessions</title>)
    response.body.should contain %(<h1 class="title">User 'bob' not found in "users" &amp; sessions</h1>)
  end

  it "sends a restrictive Content-Security-Policy with the development error page" do
    get "/" do
      raise "boom"
    end

    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.headers["Content-Security-Policy"].should eq "default-src 'none'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'"
    response.headers["X-Content-Type-Options"].should eq "nosniff"
  end

  it "doesn't reflect the request on the production error page" do
    Kemal.config.env = "production"
    get "/u/*path" do |env|
      raise "User '#{env.params.query["name"]}' not found"
    end

    request = HTTP::Request.new("GET", "/u/<script>?name=<script>")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::ExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::ExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.body.should_not contain "<script>"
    response.body.should contain "Kemal has encountered an error. (500)"
  end
end
