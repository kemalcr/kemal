require "./spec_helper"

class CustomTestHandler < HTTP::Handler
  def call(env)
    env.response << "Kemal"
    call_next env
  end
end

describe "Handler" do
  it "adds custom handler before before_*" do
    before_get "/" do |env|
      puts "Next 1"
      env.response << " is"
    end

    before_get "/" do |env|
      puts "Next 2"
      env.response << " so"
    end

    before_all "/" do
    end

    add_handler CustomTestHandler.new

    get "/" do |env|
      " Great"
    end

    Kemal.config.handlers.each do |h|
      puts h.class
    end

    request = HTTP::Request.new("GET", "/")
    client_response = call_request_on_app(request)
    client_response.status_code.should eq(200)
    client_response.body.should eq("Kemal is so Great")
  end
end
