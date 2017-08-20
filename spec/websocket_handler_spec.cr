require "./spec_helper"

describe "Kemal::WebSocketHandler" do
  it "matches on given route" do
    handler = Kemal::WebSocketHandler.new "/" { }
    headers = HTTP::Headers{
      "Upgrade"           => "websocket",
      "Connection"        => "Upgrade",
      "Sec-WebSocket-Key" => "dGhlIHNhbXBsZSBub25jZQ==",
    }
    request = HTTP::Request.new("GET", "/", headers)
    io_with_context = create_ws_request_and_return_io(handler, request)
    io_with_context.to_s.should eq("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-Websocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n")
  end

  it "fetches named url parameters" do
    handler = Kemal::WebSocketHandler.new "/:id" { |s, c| c.params.url["id"] }
    headers = HTTP::Headers{
      "Upgrade"           => "websocket",
      "Connection"        => "Upgrade",
      "Sec-WebSocket-Key" => "dGhlIHNhbXBsZSBub25jZQ==",
    }
    request = HTTP::Request.new("GET", "/1234", headers)
    io_with_context = create_ws_request_and_return_io(handler, request)
    io_with_context.to_s.should eq("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-Websocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n")
  end
end
