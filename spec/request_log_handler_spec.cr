require "log/spec"
require "./spec_helper"

describe Kemal::RequestLogHandler do
  it "creates log message for each request" do
    Log.setup(:none)

    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(IO::Memory.new)
    context = HTTP::Server::Context.new(request, response)
    logger = Kemal::RequestLogHandler.new
    Log.capture do |logs|
      logger.call(context)
      logs.check(:info, /404 GET \/ \d+.*s/)
    end
  end

  it "allows custom log message format" do
    Log.setup(:none)

    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(IO::Memory.new)
    context = HTTP::Server::Context.new(request, response)
    request_logger = Kemal::RequestLogger.new do |ctx, elapsed_time|
      "#{ctx.request.method} custom log line #{elapsed_time}"
    end
    logger = Kemal::RequestLogHandler.new(request_logger)
    Log.capture do |logs|
      logger.call(context)
      logs.check(:info, /GET custom log line \d+.*s/)
    end
  end
end
