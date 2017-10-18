require "./dsl_helper"

describe "Kemal::ExceptionHandler" do
  it "renders 404 on route not found" do
    request = HTTP::Request.new("GET", "/asd")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    subject = Kemal::ExceptionHandler.new(Kemal::Base.new)
    subject.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 404
  end

  it "renders custom error" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    app = Kemal::Base.new
    app.error 403 do
      "403 error"
    end
    app.get "/" do |env|
      env.response.status_code = 403
    end
    subject = Kemal::ExceptionHandler.new(app)
    subject.next = app.route_handler
    subject.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 403
    response.headers["Content-Type"].should eq "text/html"
    response.body.should eq "403 error"
  end

  it "renders custom 500 error" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    app = Kemal::Base.new
    app.error 500 do |env|
      "Something happened"
    end
    app.get "/" do |env|
      env.response.status_code = 500
    end
    subject = Kemal::ExceptionHandler.new(app)
    subject.next = app.route_handler
    subject.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.headers["Content-Type"].should eq "text/html"
    response.body.should eq "Something happened"
  end

  it "keeps the specified error Content-Type" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    app = Kemal::Base.new
    app.error 500 do |env|
      "Something happened"
    end
    app.get "/" do |env|
      env.response.content_type = "application/json"
      env.response.status_code = 500
    end
    subject = Kemal::ExceptionHandler.new(app)
    subject.next = app.route_handler
    subject.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.headers["Content-Type"].should eq "application/json"
    response.body.should eq "Something happened"
  end

  it "renders custom error with env and error" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    app = Kemal::Base.new
    app.error 500 do |env, err|
      err.message
    end
    app.get "/" do |env|
      env.response.content_type = "application/json"
      env.response.status_code = 500
    end
    subject = Kemal::ExceptionHandler.new(app)
    subject.next = app.route_handler
    subject.call(context)
    response.close
    io.rewind
    response = HTTP::Client::Response.from_io(io, decompress: false)
    response.status_code.should eq 500
    response.headers["Content-Type"].should eq "application/json"
    response.body.should eq "Rendered error with 500"
  end
end
