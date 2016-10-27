require "./spec_helper"

class CustomTestHandler < HTTP::Handler
  def call(env)
    env.response << "Kemal"
    call_next env
  end
end

describe "Handler" do
  it "adds custom handler before before_*" do
    filter_middleware = Kemal::Middleware::Filter.new
    filter_middleware._add_route_filter("GET", "/", :before) do |env|
      env.response << " is"
    end

    filter_middleware._add_route_filter("GET", "/", :before) do |env|
      env.response << " so"
    end
    add_handler CustomTestHandler.new

    get "/" do |env|
      " Great"
    end
    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(200)
    client_response.body.should eq("Kemal is so Great")
  end
end
