require "./spec_helper"

describe "Session" do
  it "can establish a session" do
    sid = nil
    existing = nil
    get "/" do |env|
      sess = env.session
      existing = sess["token"]?
      sess.delete("token")
      sid = sess.id
      sess["token"] = "abc"
      "Hello"
    end

    # make first request without any cookies/session
    request = HTTP::Request.new("GET", "/")
    response = call_request_on_app(request)

    # verify we got a cookie and session ID
    cookie = response.headers["Set-Cookie"]?
    cookie.should_not be_nil
    response.cookies[Kemal.config.session["name"].as(String)].value.should eq(sid)
    lastsid = sid
    existing.should be_nil

    # make second request with cookies to get session
    request = HTTP::Request.new("GET", "/", response.headers)
    response = call_request_on_app(request)

    # verify we got cookies and we could see values set
    # in the previous request
    cookie2 = response.headers["Set-Cookie"]?
    cookie2.should_not be_nil
    cookie2.should eq(cookie)
    response.cookies[Kemal.config.session["name"].as(String)].value.should eq(lastsid)
    existing.should eq("abc")
  end

  it "can prune old sessions" do
    s = Kemal::Sessions::STORE
    s.clear

    Kemal::Sessions.prune!

    id = "foo"
    s[id] = Kemal::Sessions::Session.new(id)
    s.size.should eq(1)
    Kemal::Sessions.prune!
    s.size.should eq(1)

    s[id].last_access_at = (Time.now - 1.week).epoch_ms
    Kemal::Sessions.prune!
    s.size.should eq(0)
  end
end
