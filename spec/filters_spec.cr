require "./spec_helper"

describe "Kemal::FilterHandler" do
  it "handles with upcased 'POST'" do
    filter_handler = Kemal::FilterHandler.new
    filter_handler._add_route_filter("POST", "*", :before) do |env|
      env.set "sensitive", "1"
    end
    Kemal.config.add_filter_handler(filter_handler)

    post "/sensitive_post" do |env|
      env.get "sensitive"
    end

    request = HTTP::Request.new("POST", "/sensitive_post")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(200)
    client_response.body.should eq("1")
  end

  it "handles with downcased 'post'" do
    filter_handler = Kemal::FilterHandler.new
    filter_handler._add_route_filter("POST", "*", :before) do |env|
      env.set "sensitive", "1"
    end
    Kemal.config.add_filter_handler(filter_handler)

    post "/sensitive_post" do
      "sensitive"
    end

    request = HTTP::Request.new("post", "/sensitive_post")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(200)
    client_response.body.should eq("")
  end
end
