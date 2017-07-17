require "./spec_helper"

private def create_ws_request_and_return_io(handler, request, app)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  context.app = app
  begin
    handler.call context
  rescue IO::Error
    # Raises because the IO::Memory is empty
  end
  io
end

describe "Kemal::WebSocketHandler" do
  it "doesn't match on wrong route" do
    app = Kemal::Base.new
    handler = Kemal::WebSocketHandler.new
    handler.next = Kemal::RouteHandler.new
    app.ws "/" { }
    headers = HTTP::Headers{
      "Upgrade"           => "websocket",
      "Connection"        => "Upgrade",
      "Sec-WebSocket-Key" => "dGhlIHNhbXBsZSBub25jZQ==",
    }
    request = HTTP::Request.new("GET", "/asd", headers)
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    context.app = app

    expect_raises(Kemal::Exceptions::RouteNotFound) do
      handler.call context
    end
  end

  it "matches on given route" do
    app = Kemal::Base.new
    handler = Kemal::WebSocketHandler.new
    app.ws "/" { |socket, context| socket.send("Match") }
    app.ws "/no_match" { |socket, context| socket.send "No Match" }
    headers = HTTP::Headers{
      "Upgrade"           => "websocket",
      "Connection"        => "Upgrade",
      "Sec-WebSocket-Key" => "dGhlIHNhbXBsZSBub25jZQ==",
    }
    request = HTTP::Request.new("GET", "/", headers)

    io_with_context = create_ws_request_and_return_io(handler, request, app)
    io_with_context.to_s.should eq("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-Websocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n\x81\u0005Match")
  end

  it "fetches named url parameters" do
    app = Kemal::Base.new
    handler = Kemal::WebSocketHandler.new
    app.ws "/:id" { |s, c| c.params.url["id"] }
    headers = HTTP::Headers{
      "Upgrade"           => "websocket",
      "Connection"        => "Upgrade",
      "Sec-WebSocket-Key" => "dGhlIHNhbXBsZSBub25jZQ==",
    }
    request = HTTP::Request.new("GET", "/1234", headers)
    io_with_context = create_ws_request_and_return_io(handler, request, app)
    io_with_context.to_s.should eq("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-Websocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n")
  end

  it "matches correct verb" do
    app = Kemal::Base.new
    handler = Kemal::WebSocketHandler.new
    handler.next = Kemal::RouteHandler.new
    app.ws "/" { }
    app.get "/" { "get" }
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    context.app = app
    handler.call(context)
    response.close
    io.rewind
    client_response = HTTP::Client::Response.from_io(io, decompress: false)
    client_response.body.should eq("get")
  end
end
