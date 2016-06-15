require "./spec_helper"

describe "Kemal::WebSocketHandler" do
  it "doesn't match on wrong route" do
    handler = Kemal::WebSocketHandler.new "/" { }
    headers = HTTP::Headers{
      "Upgrade"           => "websocket",
      "Connection"        => "Upgrade",
      "Sec-WebSocket-Key" => "dGhlIHNhbXBsZSBub25jZQ==",
    }
    request = HTTP::Request.new("GET", "/asd", headers)
    io_with_context = create_request_and_return_io(handler, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.status_code.should eq(404)
  end

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
end
