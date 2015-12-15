require "./spec_helper"

describe "Kemal::WebsocketHandler" do

  it "doesn't match on wrong route" do
    handler = Kemal::WebsocketHandler.new "/" { }
    headers = HTTP::Headers{
      "Upgrade":           "websocket",
      "Connection":        "Upgrade",
      "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==",
    }
    request = HTTP::Request.new("GET", "/asd", headers)
    response = handler.call request
    response.status_code.should eq(404)
  end

  it "matches on given route" do
    handler = Kemal::WebsocketHandler.new "/" { }
    headers = HTTP::Headers{
      "Upgrade":           "websocket",
      "Connection":        "Upgrade",
      "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==",
    }
    request = HTTP::Request.new("GET", "/", headers)
    response = handler.call request
    response.status_code.should eq(101)
    response.headers["Upgrade"].should eq("websocket")
    response.headers["Connection"].should eq("Upgrade")
    response.headers["Sec-WebSocket-Accept"].should eq("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    response.upgrade_handler.should_not be_nil
  end

  it "doesn't mix http and ws on same route" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      "hello #{env.params["message"]}"
    end

    ws_handler = Kemal::WebsocketHandler.new "/" { }
    headers = HTTP::Headers{
      "Upgrade":           "websocket",
      "Connection":        "Upgrade",
      "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==",
    }

    # HTTP Request
    request = HTTP::Request.new("GET", "/?message=world")
    response = kemal.call(request)
    response.body.should eq("hello world")

    # Websocket request
    request = HTTP::Request.new("GET", "/", headers)
    response = ws_handler.call request
    response.status_code.should eq(101)
    response.headers["Upgrade"].should eq("websocket")
    response.headers["Connection"].should eq("Upgrade")
    response.headers["Sec-WebSocket-Accept"].should eq("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    response.upgrade_handler.should_not be_nil
  end

end
