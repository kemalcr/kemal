require "./spec_helper"

describe "Macros" do
  describe "#basic_auth" do
    it "adds HTTPBasicAuthHandler" do
      basic_auth "serdar", "123"
      Kemal.config.handlers.size.should eq 6
    end
  end

  describe "#public_folder" do
    it "sets public folder" do
      public_folder "/some/path/to/folder"
      Kemal.config.public_folder.should eq("/some/path/to/folder")
    end
  end

  describe "#add_handler" do
    it "adds a custom handler" do
      add_handler CustomTestHandler.new
      Kemal.config.handlers.size.should eq 6
    end
  end

  describe "#logging" do
    it "sets logging status" do
      logging false
      Kemal.config.logging.should eq false
    end
    it "sets a custom logger" do
      config = Kemal::Config::INSTANCE
      logger CustomLogHandler.new
      config.handlers.last.should be_a(CustomLogHandler)
      config.logger.should be_a(CustomLogHandler)
    end
  end

  describe "#return_with" do
    it "can break block with return_with macro" do
      get "/non-breaking" do |env|
        "hello"
        "world"
      end
      request = HTTP::Request.new("GET", "/non-breaking")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.body.should eq("world")

      get "/breaking" do |env|
        return_with env, 404, "hello"
        "world"
      end
      request = HTTP::Request.new("GET", "/breaking")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(404)
      client_response.body.should eq("hello")
    end

    it "can break block with return_with macro using default values" do
      get "/" do |env|
        return_with env
        "world"
      end
      request = HTTP::Request.new("GET", "/")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.body.should eq("")
    end
  end

  describe "#headers" do
    it "can add headers" do
      get "/headers" do |env|
        env.response.headers.add "Content-Type", "image/png"
        headers env, {
          "Access-Control-Allow-Origin" => "*",
          "Content-Type"                => "text/plain",
        }
      end

      request = HTTP::Request.new("GET", "/headers")
      response = call_request_on_app(request)
      response.headers["Access-Control-Allow-Origin"].should eq("*")
      response.headers["Content-Type"].should eq("text/plain")
    end
  end

  describe "#send_file" do
    it "sends file with given path and default mime-type" do
      get "/" do |env|
        send_file env, "./spec/asset/hello.ecr"
      end

      request = HTTP::Request.new("GET", "/")
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.headers["Content-Type"].should eq("application/octet-stream")
      response.headers["Content-Length"].should eq("20")
    end

    it "sends file with given path and given mime-type" do
      get "/" do |env|
        send_file env, "./spec/asset/hello.ecr", "image/jpeg"
      end

      request = HTTP::Request.new("GET", "/")
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.headers["Content-Type"].should eq("image/jpeg")
      response.headers["Content-Length"].should eq("20")
    end
  end
end
