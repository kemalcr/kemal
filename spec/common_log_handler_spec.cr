require "./spec_helper"

class ErrHandler < Kemal::Handler
  def call(env); env.response.status_code = 418; call_next(env); end
end
describe "Kemal::CommonLogHandler" do
  it "logs to the given IO" do
    config = Kemal.config
    io = IO::Memory.new
    logger = Kemal::CommonLogHandler.new io
    logger.write "Something"
    io.to_s.should eq "Something"
  end

  it "creates log message for each request" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    context_io = IO::Memory.new
    response = HTTP::Server::Response.new(context_io)
    context = HTTP::Server::Context.new(request, response)
    logger = Kemal::CommonLogHandler.new io
    logger.call(context)
    io.to_s.should_not be nil
  end

  context "with status code changes" do

    it "logs a 200 status" do
      get "/" { |env| "Hello" }
      request = HTTP::Request.new("GET", "/")
      io = IO::Memory.new
      logger = Kemal::CommonLogHandler.new io
      Kemal.config.add_handler(logger)
      call_request_on_app(request)
      io.to_s.should match(/200\sGET/)
    end

    it "logs a 418 status" do
      error 418 { |env, err| "I'm a teapot" }
      get "/" { |env| "Hello" }
      request = HTTP::Request.new("GET", "/")
      io = IO::Memory.new
      logger = Kemal::CommonLogHandler.new(io)
      Kemal.config.add_handler(logger)
      Kemal.config.add_handler(Kemal::CommonExceptionHandler.new)
      Kemal.config.add_handler(ErrHandler.new)
      response = call_request_on_app(request)
      io.to_s.should match(/418\sGET/)
    end

    it "logs a 500 status" do
      error 500 { |env, err| "Oops!" }
      get "/" { |env| raise "I did it again" }
      request = HTTP::Request.new("GET", "/")
      io = IO::Memory.new
      logger = Kemal::CommonLogHandler.new(io)
      logger logger
      Kemal.config.add_handler(logger)
      Kemal.config.add_handler(Kemal::CommonExceptionHandler.new)
      response = call_request_on_app(request)
      io.to_s.should match(/500\sGET/)
    end
  end
end
