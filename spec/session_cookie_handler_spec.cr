require "./spec_helper"

describe Kemal::SessionCookieHandler do

  it "raises an ArgumentError if secret is not provided" do
    request = HTTP::Request.new("GET", "/")
    io = MemoryIO.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    session = Kemal::SessionCookieHandler::INSTANCE
    context.session["authorized"] = "true"
    begin
      session.call(context)
    rescue ex : ArgumentError
      ex.message.should eq "Please provide a Secret. You may generate one using: \ncrystal eval \"require \"secure_random\"; puts SecureRandom.hex(64)\""
    end
  end

  it "sets a cookie" do
    request = HTTP::Request.new("GET", "/")
    io = MemoryIO.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    session = Kemal::SessionCookieHandler::INSTANCE
    session.secret = "0c04a88341ec9ffd2794a0d35c9d58109d8fff32dfc48194c2a2a8fc62091190920436d58de598ca9b44dd20e40b1ab431f6dcaa40b13642b69d0edff73d7374"
    session.call(context)
    context.response.headers.has_key?("set-cookie").should be_true
  end

  it "encodes the session data" do
    request = HTTP::Request.new("GET", "/")
    io = MemoryIO.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    session = Kemal::SessionCookieHandler::INSTANCE
    session.secret = "0c04a88341ec9ffd2794a0d35c9d58109d8fff32dfc48194c2a2a8fc62091190920436d58de598ca9b44dd20e40b1ab431f6dcaa40b13642b69d0edff73d7374"
    context.session["authorized"] = "true"
    session.call(context)
    cookie = context.response.headers["set-cookie"]
    cookie.should eq "kemal.session=d5374f304c4a343e14fca421e4c372c777207337--eyJhdXRob3JpemVkIjoidHJ1ZSJ9%0A; path=/"
  end
  
end



