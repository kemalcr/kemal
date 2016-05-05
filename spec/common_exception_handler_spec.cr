require "./spec_helper"

describe "Kemal::CommonExceptionHandler" do
  # it "renders 404 on route not found" do
  #   get "/" do |env|
  #     "Hello"
  #   end
  #
  #   request = HTTP::Request.new("GET", "/asd")
  #   client_response = call_request_on_app(request)
  #   client_response.status_code.should eq 404
  # end
  #
  # it "renders custom error" do
  #   error 403 do
  #     "403 error"
  #   end
  #
  #   get "/" do |env|
  #     env.response.status_code = 403
  #   end
  #
  #   request = HTTP::Request.new("GET", "/")
  #   client_response = call_request_on_app(request)
  #   client_response.status_code.should eq 403
  #   client_response.body.should eq "403 error"
  # end
end
