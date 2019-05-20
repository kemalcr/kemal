require "./spec_helper"

describe "Kemal::Namespace" do
  it "namespace" do
    namespace "/n" do
      get "/" do
        "hello"
      end
    end
    request = HTTP::Request.new("GET", "/n")
    client_response = call_request_on_app(request)
    client_response.body.should eq("hello")
  end

  it "nested namespace" do
    namespace "/n" do
      namespace "/n" do
        get "/" do
          "hello"
        end
      end
    end
    request = HTTP::Request.new("GET", "/n/n")
    client_response = call_request_on_app(request)
    client_response.body.should eq("hello")
  end

  it "3 levle nested namespace" do
    namespace "/n" do
      namespace "/n" do
        namespace "/n" do
          get "/" do
            "hello"
          end
        end
      end
    end
    request = HTTP::Request.new("GET", "/n/n/n")
    client_response = call_request_on_app(request)
    client_response.body.should eq("hello")
  end
end
