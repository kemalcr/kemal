require "./spec_helper"

def ws_upgrade_headers_for_origin(origin : String? = nil)
  h = HTTP::Headers{
    "Upgrade"               => "websocket",
    "Connection"            => "Upgrade",
    "Sec-WebSocket-Key"     => "dGhlIHNhbXBsZSBub25jZQ==",
    "Sec-WebSocket-Version" => "13",
  }
  h["Origin"] = origin if origin
  h
end

describe "Kemal::WebSocketHandler" do
  it "doesn't match on wrong route" do
    handler = Kemal::WebSocketHandler::INSTANCE
    handler.next = Kemal::RouteHandler::INSTANCE
    ws "/" { }
    headers = HTTP::Headers{
      "Upgrade"           => "websocket",
      "Connection"        => "Upgrade",
      "Sec-WebSocket-Key" => "dGhlIHNhbXBsZSBub25jZQ==",
    }
    request = HTTP::Request.new("GET", "/asd", headers)
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    expect_raises(Kemal::Exceptions::RouteNotFound) do
      handler.call context
    end
  end

  it "matches on given route" do
    handler = Kemal::WebSocketHandler::INSTANCE
    ws("/", &.send("Match"))
    ws("/no_match", &.send("No Match"))
    headers = HTTP::Headers{
      "Upgrade"               => "websocket",
      "Connection"            => "Upgrade",
      "Sec-WebSocket-Key"     => "dGhlIHNhbXBsZSBub25jZQ==",
      "Sec-WebSocket-Version" => "13",
    }
    request = HTTP::Request.new("GET", "/", headers)

    io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
    io_with_context.to_s.should eq("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n\x81\u0005Match")
  end

  it "fetches named url parameters" do
    handler = Kemal::WebSocketHandler::INSTANCE
    ws "/:id" { |_, context| context.ws_route_lookup.params["id"] }
    headers = HTTP::Headers{
      "Upgrade"               => "websocket",
      "Connection"            => "Upgrade",
      "Sec-WebSocket-Key"     => "dGhlIHNhbXBsZSBub25jZQ==",
      "Sec-WebSocket-Version" => "13",
    }
    request = HTTP::Request.new("GET", "/1234", headers)
    io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
    io_with_context.to_s.should eq("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n")
  end

  it "matches correct verb" do
    handler = Kemal::WebSocketHandler::INSTANCE
    handler.next = Kemal::RouteHandler::INSTANCE
    ws "/" { }
    get "/" { "get" }
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    handler.call(context)
    response.close
    io.rewind
    client_response = HTTP::Client::Response.from_io(io, decompress: false)
    client_response.body.should eq("get")
  end

  describe "websocket_allowed_origins" do
    it "rejects 403 when allowlist is set and Origin is missing" do
      Kemal.config.websocket_allowed_origins = ["https://app.example.com"]
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      request = HTTP::Request.new("GET", "/", ws_upgrade_headers_for_origin)
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(request, response)
      handler.call(context)
      response.close
      io.rewind
      client_response = HTTP::Client::Response.from_io(io, decompress: false)
      client_response.status_code.should eq(403)
      client_response.body.should eq("Forbidden")
    end

    it "rejects 403 when Origin is not in allowlist" do
      Kemal.config.websocket_allowed_origins = ["https://app.example.com"]
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      request = HTTP::Request.new("GET", "/", ws_upgrade_headers_for_origin("https://evil.example"))
      io = IO::Memory.new
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(request, response)
      handler.call(context)
      response.close
      io.rewind
      client_response = HTTP::Client::Response.from_io(io, decompress: false)
      client_response.status_code.should eq(403)
    end

    it "allows upgrade when Origin matches allowlist" do
      Kemal.config.websocket_allowed_origins = ["https://App.EXAMPLE.com"]
      handler = Kemal::WebSocketHandler::INSTANCE
      ws("/", &.send("ok"))
      request = HTTP::Request.new("GET", "/", ws_upgrade_headers_for_origin("https://app.example.com"))
      io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
      io_with_context.to_s.should contain("101 Switching Protocols")
      io_with_context.to_s.should contain("\x81\u0002ok")
    end

    it "normalizes default https port against allowlist" do
      Kemal.config.websocket_allowed_origins = ["https://example.com"]
      handler = Kemal::WebSocketHandler::INSTANCE
      ws("/", &.send("x"))
      request = HTTP::Request.new("GET", "/", ws_upgrade_headers_for_origin("https://example.com:443"))
      io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
      io_with_context.to_s.should contain("101 Switching Protocols")
    end
  end
end
