require "./spec_helper"

describe "Kemal::FilterHandler" do
  it "handles with upcased 'POST'" do
    before_post do |env|
      env.set "sensitive", "1"
    end

    post "/sensitive_post" do |env|
      env.get "sensitive"
    end

    request = HTTP::Request.new("POST", "/sensitive_post")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(200)
    client_response.body.should eq("1")
  end

  it "handles with downcased 'post'" do
    before_post do |env|
      env.set "sensitive", "1"
    end

    post "/sensitive_post" do |env|
      "sensitive"
    end

    request = HTTP::Request.new("post", "/sensitive_post")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(200)
    client_response.body.should eq("")
  end
end