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
end
