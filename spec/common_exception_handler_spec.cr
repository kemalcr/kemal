require "./spec_helper"

describe "Kemal::CommonExceptionHandler" do
  it "renders 404 on route not found" do
    get "/" do |env|
      "Hello"
    end

    request = HTTP::Request.new("GET", "/asd")
    io = MemoryIO.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::CommonExceptionHandler::INSTANCE.call(context)
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
    io = MemoryIO.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::CommonExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::CommonExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 403
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
    io = MemoryIO.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::CommonExceptionHandler::INSTANCE.next = Kemal::RouteHandler::INSTANCE
    Kemal::CommonExceptionHandler::INSTANCE.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.body.should eq "Something happened"
  end
end
