require "./spec_helper"

describe Kemal::EventStream do
  it "sends events with SSE headers" do
    sse "/events" do |stream, _|
      stream.send("hello")
    end

    request = HTTP::Request.new("GET", "/events")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(200)
    client_response.headers["Content-Type"].should eq("text/event-stream; charset=utf-8")
    client_response.headers["Cache-Control"].should eq("no-cache")
    client_response.headers["X-Accel-Buffering"].should eq("no")
    client_response.body.should eq("data: hello\n\n")
  end

  it "sends event with name, id, and retry" do
    sse "/events" do |stream, _|
      stream.send("update", event: "tick", id: 42, retry: 3.seconds)
    end

    request = HTTP::Request.new("GET", "/events")
    client_response = call_request_on_app(request)
    client_response.body.should eq("event: tick\nid: 42\nretry: 3000\ndata: update\n\n")
  end

  it "does not overflow on retry spans beyond Int32 milliseconds" do
    # 60 days is 5_184_000_000 ms, well past Int32::MAX (~2.1e9).
    sse "/events" do |stream, _|
      stream.send("update", retry: 60.days)
    end

    request = HTTP::Request.new("GET", "/events")
    client_response = call_request_on_app(request)
    client_response.body.should eq("retry: 5184000000\ndata: update\n\n")
  end

  it "emits a zero retry span" do
    sse "/events" do |stream, _|
      stream.send("update", retry: 0.seconds)
    end

    request = HTTP::Request.new("GET", "/events")
    client_response = call_request_on_app(request)
    client_response.body.should eq("retry: 0\ndata: update\n\n")
  end

  it "omits negative retry spans" do
    sse "/events" do |stream, _|
      stream.send("update", retry: -3.seconds)
    end

    request = HTTP::Request.new("GET", "/events")
    client_response = call_request_on_app(request)
    client_response.body.should eq("data: update\n\n")
  end

  it "splits multi-line data into separate data fields" do
    sse "/events" do |stream, _|
      stream.send("line one\nline two")
    end

    request = HTTP::Request.new("GET", "/events")
    client_response = call_request_on_app(request)
    client_response.body.should eq("data: line one\ndata: line two\n\n")
  end

  it "rejects LF, CR, and CRLF in event names" do
    {"tick\ndata: x", "tick\rdata: x", "tick\r\ndata: x"}.each do |event|
      io = IO::Memory.new
      stream = Kemal::EventStream.new(HTTP::Server::Response.new(io))
      expect_raises(ArgumentError, "SSE event must not contain CR or LF") do
        stream.send("hello", event: event)
      end
    end
  end

  it "rejects LF, CR, and CRLF in ids" do
    {"7\nevent: x", "7\revent: x", "7\r\nevent: x"}.each do |id|
      io = IO::Memory.new
      stream = Kemal::EventStream.new(HTTP::Server::Response.new(io))
      expect_raises(ArgumentError, "SSE id must not contain CR or LF") do
        stream.send("hello", id: id)
      end
    end
  end

  it "treats bare CR in data as a line break to prevent field smuggling" do
    sse "/events" do |stream, _|
      stream.send("safe\rdata: smuggled-via-CR")
    end

    request = HTTP::Request.new("GET", "/events")
    client_response = call_request_on_app(request)
    client_response.body.should eq("data: safe\ndata: data: smuggled-via-CR\n\n")
    client_response.body.should_not contain("\r")
  end

  it "treats CRLF in data as a line break to prevent field smuggling" do
    sse "/events" do |stream, _|
      stream.send("safe\r\nevent: injected\r\ndata: owned")
    end

    request = HTTP::Request.new("GET", "/events")
    client_response = call_request_on_app(request)
    client_response.body.should eq("data: safe\ndata: event: injected\ndata: data: owned\n\n")
  end

  it "sends keep-alive comments" do
    sse "/events" do |stream, _|
      stream.comment("ping")
    end

    request = HTTP::Request.new("GET", "/events")
    client_response = call_request_on_app(request)
    client_response.body.should eq(": ping\n\n")
  end

  it "splits multi-line comments to prevent SSE injection" do
    sse "/events" do |stream, _|
      stream.comment("ping\nevent: injected\ndata: owned")
    end

    request = HTTP::Request.new("GET", "/events")
    client_response = call_request_on_app(request)
    client_response.body.should eq(": ping\n: event: injected\n: data: owned\n\n")
  end

  it "supports url parameters" do
    sse "/events/:channel" do |stream, env|
      stream.send(env.params.url["channel"])
    end

    request = HTTP::Request.new("GET", "/events/news")
    client_response = call_request_on_app(request)
    client_response.body.should eq("data: news\n\n")
  end

  it "does not append extra body when handler returns EventStream" do
    sse "/events" do |stream, _|
      stream.send("only this")
    end

    request = HTTP::Request.new("GET", "/events")
    client_response = call_request_on_app(request)
    client_response.body.should eq("data: only this\n\n")
  end

  it "requires path to start with /" do
    expect_raises Kemal::Exceptions::InvalidPathStartException do
      sse "events" { |_, _| }
    end
  end

  it "registers as GET route only" do
    sse "/events" { |_, _| }

    Kemal::RouteHandler::INSTANCE.lookup_route("GET", "/events").found?.should be_true
    Kemal::RouteHandler::INSTANCE.lookup_route("POST", "/events").found?.should be_false
  end
end

describe "Kemal::Router SSE" do
  it "registers SSE routes with prefix" do
    router = Kemal::Router.new
    router.sse "/events" do |stream, _|
      stream.send("mounted")
    end

    mount "/api", router

    request = HTTP::Request.new("GET", "/api/events")
    client_response = call_request_on_app(request)
    client_response.body.should eq("data: mounted\n\n")
  end
end
