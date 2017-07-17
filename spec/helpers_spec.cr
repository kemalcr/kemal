require "./spec_helper"

describe "Macros" do
  describe "#public_folder" do
    it "sets public folder" do
      public_folder "/some/path/to/folder"
      Kemal.config.public_folder.should eq("/some/path/to/folder")
    end
  end

  describe "#add_handler" do
    it "adds a custom handler" do
      app = Kemal::Application.new
      app.add_handler CustomTestHandler.new
      app.setup
      app.handlers.size.should eq 8
    end
  end

  describe "#logging" do
    it "sets logging status" do
      logging false
      Kemal.config.logging?.should be_false
    end

    it "sets a custom logger" do
      logger CustomLogHandler.new
      Kemal.application.logger.should be_a(CustomLogHandler)
    end
  end

  describe "#halt" do
    it "can break block with halt macro" do
      app = Kemal::Base.new
      app.get "/non-breaking" do |env|
        "hello"
        "world"
      end
      request = HTTP::Request.new("GET", "/non-breaking")
      client_response = call_request_on_app(app, request)
      client_response.status_code.should eq(200)
      client_response.body.should eq("world")

      app.get "/breaking" do |env|
        halt env, 404, "hello"
        "world"
      end
      request = HTTP::Request.new("GET", "/breaking")
      client_response = call_request_on_app(app, request)
      client_response.status_code.should eq(404)
      client_response.body.should eq("hello")
    end

    it "can break block with halt macro using default values" do
      app = Kemal::Base.new
      app.get "/" do |env|
        halt env
        "world"
      end
      request = HTTP::Request.new("GET", "/")
      client_response = call_request_on_app(app, request)
      client_response.status_code.should eq(200)
      client_response.body.should eq("")
    end
  end

  describe "#headers" do
    it "can add headers" do
      app = Kemal::Base.new
      app.get "/headers" do |env|
        env.response.headers.add "Content-Type", "image/png"
        headers env, {
          "Access-Control-Allow-Origin" => "*",
          "Content-Type"                => "text/plain",
        }
      end
      request = HTTP::Request.new("GET", "/headers")
      response = call_request_on_app(app, request)
      response.headers["Access-Control-Allow-Origin"].should eq("*")
      response.headers["Content-Type"].should eq("text/plain")
    end
  end

  describe "#send_file" do
    it "sends file with given path and default mime-type" do
      app = Kemal::Base.new
      app.get "/" do |env|
        send_file env, "./spec/asset/hello.ecr"
      end

      request = HTTP::Request.new("GET", "/")
      response = call_request_on_app(app, request)
      response.status_code.should eq(200)
      response.headers["Content-Type"].should eq("application/octet-stream")
      response.headers["Content-Length"].should eq("18")
    end

    it "sends file with given path and given mime-type" do
      app = Kemal::Base.new
      app.get "/" do |env|
        send_file env, "./spec/asset/hello.ecr", "image/jpeg"
      end

      request = HTTP::Request.new("GET", "/")
      response = call_request_on_app(app, request)
      response.status_code.should eq(200)
      response.headers["Content-Type"].should eq("image/jpeg")
      response.headers["Content-Length"].should eq("18")
    end

    it "sends file with binary stream" do
      app = Kemal::Base.new
      app.get "/" do |env|
        send_file env, "Serdar".to_slice
      end

      request = HTTP::Request.new("GET", "/")
      response = call_request_on_app(app, request)
      response.status_code.should eq(200)
      response.headers["Content-Type"].should eq("application/octet-stream")
      response.headers["Content-Length"].should eq("6")
    end
  end

  describe "#gzip" do
    it "adds HTTP::CompressHandler to handlers" do
      gzip true
      Kemal.application.setup
      Kemal.application.handlers[4].should be_a(HTTP::CompressHandler)
    end
  end

  describe "#serve_static" do
    it "should disable static file hosting" do
      serve_static false
      Kemal.config.serve_static.should be_false
    end

    it "should disble enable gzip and dir_listing" do
      serve_static({"gzip" => true, "dir_listing" => true})
      conf = Kemal.config.serve_static
      conf.is_a?(Hash).should be_true # Can't use be_a(Hash) because Hash can't be used as generic argument
      if conf.is_a?(Hash)
        conf["gzip"].should be_true
        conf["dir_listing"].should be_true
      end
    end
  end
end
