require "./spec_helper"
require "socket"

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

def call_ws_handler_response(handler, request) : HTTP::Client::Response
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler.call(context)
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, decompress: false)
end

def assert_websocket_forbidden_closed(response : HTTP::Client::Response)
  response.status_code.should eq(403)
  response.body.should eq("Forbidden")
  response.headers["Connection"]?.try(&.downcase).should eq("close")
end

def assert_websocket_method_not_allowed(response : HTTP::Client::Response)
  response.status_code.should eq(405)
  response.headers["Allow"]?.should eq("GET")
  response.headers["Connection"]?.try(&.downcase).should eq("close")
  response.headers["Content-Type"]?.should eq("text/plain; charset=UTF-8")
  response.body.should eq("Method Not Allowed")
end

# Raw TCP exchange against a live HTTP::Server (needed to exercise Crystal keep-alive).
def raw_http_exchange(host : String, port : Int32, payload : String, read_seconds = 1) : String
  socket = nil.as(TCPSocket?)
  20.times do
    socket = TCPSocket.new(host, port) rescue nil
    break if socket
    sleep 10.milliseconds
  end
  raise "server did not accept connections" unless socket

  socket.write(payload.to_slice)
  socket.flush
  socket.read_timeout = read_seconds.seconds
  data = read_socket_until_timeout(socket)
  socket.close
  data
end

def read_socket_until_timeout(socket : TCPSocket) : String
  data = IO::Memory.new
  buffer = Bytes.new(8192)
  while (n = socket.read(buffer)) > 0
    data.write(buffer[0, n])
  end
  data.to_s
rescue IO::TimeoutError
  data.to_s
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
    headers = ws_upgrade_headers_for_origin("http://localhost")
    headers["Host"] = "localhost"
    request = HTTP::Request.new("GET", "/", headers)

    io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
    io_with_context.to_s.should eq("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n\x81\u0005Match")
  end

  it "fetches named url parameters" do
    handler = Kemal::WebSocketHandler::INSTANCE
    ws "/:id" { |_, context| context.ws_route_lookup.params["id"] }
    headers = ws_upgrade_headers_for_origin("http://localhost")
    headers["Host"] = "localhost"
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
    client_response = call_ws_handler_response(handler, request)
    client_response.body.should eq("get")
  end

  describe "handshake method (RFC 6455)" do
    %w[POST QUERY HEAD].each do |method|
      it "rejects a #{method} upgrade request with 405 Method Not Allowed" do
        handler = Kemal::WebSocketHandler::INSTANCE
        ws "/chat" { }
        headers = ws_upgrade_headers_for_origin("http://localhost")
        headers["Host"] = "localhost"
        request = HTTP::Request.new(method, "/chat", headers)
        assert_websocket_method_not_allowed(call_ws_handler_response(handler, request))
      end
    end

    it "rejects a non-GET upgrade with 405 before the Origin check" do
      Kemal.config.websocket_allowed_origins = ["https://app.example.com"]
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/chat" { }
      request = HTTP::Request.new("POST", "/chat", ws_upgrade_headers_for_origin("https://evil.example"))
      assert_websocket_method_not_allowed(call_ws_handler_response(handler, request))
    end

    it "passes a non-GET request without upgrade headers to the next handler" do
      handler = Kemal::WebSocketHandler::INSTANCE
      handler.next = Kemal::RouteHandler::INSTANCE
      ws "/" { }
      post "/" { "post" }
      request = HTTP::Request.new("POST", "/")
      client_response = call_ws_handler_response(handler, request)
      client_response.body.should eq("post")
    end
  end

  describe "websocket_allowed_origins" do
    it "rejects 403 when allowlist is set and Origin is missing" do
      Kemal.config.websocket_allowed_origins = ["https://app.example.com"]
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      request = HTTP::Request.new("GET", "/", ws_upgrade_headers_for_origin)
      assert_websocket_forbidden_closed(call_ws_handler_response(handler, request))
    end

    it "rejects 403 when Origin is not in allowlist" do
      Kemal.config.websocket_allowed_origins = ["https://app.example.com"]
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      request = HTTP::Request.new("GET", "/", ws_upgrade_headers_for_origin("https://evil.example"))
      assert_websocket_forbidden_closed(call_ws_handler_response(handler, request))
    end

    it "sets Connection: close on Origin rejection with compound Connection token" do
      Kemal.config.websocket_allowed_origins = ["https://app.example.com"]
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      headers = ws_upgrade_headers_for_origin("https://evil.example")
      headers["Connection"] = "keep-alive, Upgrade"
      request = HTTP::Request.new("GET", "/", headers)
      assert_websocket_forbidden_closed(call_ws_handler_response(handler, request))
    end

    it "rejects malformed Origin with 403 instead of 500" do
      Kemal.config.websocket_allowed_origins = ["https://app.example.com"]
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      request = HTTP::Request.new("GET", "/", ws_upgrade_headers_for_origin("http://a:b"))
      assert_websocket_forbidden_closed(call_ws_handler_response(handler, request))
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

    it "allows same origin by default (Origin matches Host)" do
      Kemal.config.websocket_allowed_origins = [] of String
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/", &.send("ok")
      headers = ws_upgrade_headers_for_origin("http://localhost")
      headers["Host"] = "localhost"
      request = HTTP::Request.new("GET", "/", headers)
      io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
      io_with_context.to_s.should contain("101 Switching Protocols")
    end

    it "allows https Origin against Host when TLS is terminated upstream" do
      Kemal.config.websocket_allowed_origins = [] of String
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/", &.send("ok")
      headers = ws_upgrade_headers_for_origin("https://app.example.com")
      headers["Host"] = "app.example.com"
      request = HTTP::Request.new("GET", "/", headers)
      io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
      io_with_context.to_s.should contain("101 Switching Protocols")
    end

    it "allows same origin with non-default port" do
      Kemal.config.websocket_allowed_origins = [] of String
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/", &.send("ok")
      headers = ws_upgrade_headers_for_origin("http://localhost:3000")
      headers["Host"] = "localhost:3000"
      request = HTTP::Request.new("GET", "/", headers)
      io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
      io_with_context.to_s.should contain("101 Switching Protocols")
    end

    it "rejects 403 when default config and Origin port does not match Host" do
      Kemal.config.websocket_allowed_origins = [] of String
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      headers = ws_upgrade_headers_for_origin("http://localhost:3000")
      headers["Host"] = "localhost"
      request = HTTP::Request.new("GET", "/", headers)
      assert_websocket_forbidden_closed(call_ws_handler_response(handler, request))
    end

    it "rejects 403 when default config and Origin does not match Host" do
      Kemal.config.websocket_allowed_origins = [] of String
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      headers = ws_upgrade_headers_for_origin("https://evil.com")
      headers["Host"] = "localhost"
      request = HTTP::Request.new("GET", "/", headers)
      assert_websocket_forbidden_closed(call_ws_handler_response(handler, request))
    end

    it "rejects 403 when default config and Origin is missing" do
      Kemal.config.websocket_allowed_origins = [] of String
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      headers = ws_upgrade_headers_for_origin
      headers["Host"] = "localhost"
      request = HTTP::Request.new("GET", "/", headers)
      assert_websocket_forbidden_closed(call_ws_handler_response(handler, request))
    end

    it "rejects 403 when default config and Host is missing" do
      Kemal.config.websocket_allowed_origins = [] of String
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      request = HTTP::Request.new("GET", "/", ws_upgrade_headers_for_origin("http://localhost"))
      assert_websocket_forbidden_closed(call_ws_handler_response(handler, request))
    end

    it "rejects 403 when Origin is empty string" do
      Kemal.config.websocket_allowed_origins = [] of String
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      headers = ws_upgrade_headers_for_origin("")
      headers["Host"] = "localhost"
      request = HTTP::Request.new("GET", "/", headers)
      assert_websocket_forbidden_closed(call_ws_handler_response(handler, request))
    end

    it "rejects 403 for opaque null Origin under default same-origin policy" do
      Kemal.config.websocket_allowed_origins = [] of String
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/" { }
      headers = ws_upgrade_headers_for_origin("null")
      headers["Host"] = "localhost"
      request = HTTP::Request.new("GET", "/", headers)
      assert_websocket_forbidden_closed(call_ws_handler_response(handler, request))
    end

    it "allows wildcard origin when '*' is in allowlist" do
      Kemal.config.websocket_allowed_origins = ["*"]
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/", &.send("ok")
      request = HTTP::Request.new("GET", "/", ws_upgrade_headers_for_origin("https://anything.com"))
      io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
      io_with_context.to_s.should contain("101 Switching Protocols")
    end

    it "allows missing Origin when '*' is in allowlist" do
      Kemal.config.websocket_allowed_origins = ["*"]
      handler = Kemal::WebSocketHandler::INSTANCE
      ws "/", &.send("ok")
      request = HTTP::Request.new("GET", "/", ws_upgrade_headers_for_origin)
      io_with_context = create_ws_request_and_return_io_and_context(handler, request)[0]
      io_with_context.to_s.should contain("101 Switching Protocols")
    end
  end

  describe "WebSocket connection smuggling" do
    it "does not serve a pipelined HTTP request after a rejected upgrade" do
      # PoC-shaped regression: compound Connection keeps the request classified as an
      # upgrade (and fails Origin), but Connection: close on the 403 must stop the
      # HTTP::Server keep-alive loop from reading the pipelined GET /secret.
      Kemal.config.websocket_allowed_origins = ["https://app.example.com"]
      Kemal.config.env = "test"
      Kemal.config.logging = false

      ws "/chat" { }
      get "/secret" { "INTERNAL SECRET" }

      Kemal.config.setup
      server = HTTP::Server.new(Kemal.config.handlers)
      address = server.bind_tcp("127.0.0.1", 0)
      spawn { server.listen }

      payload = String.build do |b|
        b << "GET /chat HTTP/1.1\r\n"
        b << "Host: 127.0.0.1\r\n"
        b << "Upgrade: websocket\r\n"
        b << "Connection: keep-alive, Upgrade\r\n"
        b << "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
        b << "Sec-WebSocket-Version: 13\r\n"
        b << "Origin: https://evil.example\r\n"
        b << "\r\n"
        b << "GET /secret HTTP/1.1\r\n"
        b << "Host: 127.0.0.1\r\n"
        b << "\r\n"
      end

      raw = raw_http_exchange("127.0.0.1", address.port, payload)
      server.close

      status_lines = raw.scan(/HTTP\/1\.1 \d{3}[^\r\n]*/).map(&.[0])
      status_lines.size.should eq(1)
      status_lines[0].should eq("HTTP/1.1 403 Forbidden")
      raw.should match(/connection:\s*close/i)
      raw.includes?("INTERNAL SECRET").should be_false
    end

    it "does not serve a pipelined HTTP request after a 405 method rejection" do
      # Same PoC shape as the 403 spec above, but through the non-GET rejection
      # path: even with an allowed (same-origin) Origin, a POST upgrade must get
      # a single 405 and Connection: close must stop the keep-alive loop from
      # reading the pipelined GET /secret.
      Kemal.config.env = "test"
      Kemal.config.logging = false

      ws "/chat" { }
      get "/secret" { "INTERNAL SECRET" }

      Kemal.config.setup
      server = HTTP::Server.new(Kemal.config.handlers)
      address = server.bind_tcp("127.0.0.1", 0)
      spawn { server.listen }

      payload = String.build do |b|
        b << "POST /chat HTTP/1.1\r\n"
        b << "Host: 127.0.0.1\r\n"
        b << "Upgrade: websocket\r\n"
        b << "Connection: keep-alive, Upgrade\r\n"
        b << "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
        b << "Sec-WebSocket-Version: 13\r\n"
        b << "Origin: http://127.0.0.1\r\n"
        b << "\r\n"
        b << "GET /secret HTTP/1.1\r\n"
        b << "Host: 127.0.0.1\r\n"
        b << "\r\n"
      end

      raw = raw_http_exchange("127.0.0.1", address.port, payload)
      server.close

      status_lines = raw.scan(/HTTP\/1\.1 \d{3}[^\r\n]*/).map(&.[0])
      status_lines.size.should eq(1)
      status_lines[0].should eq("HTTP/1.1 405 Method Not Allowed")
      raw.should match(/allow:\s*GET/i)
      raw.should match(/connection:\s*close/i)
      raw.includes?("INTERNAL SECRET").should be_false
    end
  end
end
