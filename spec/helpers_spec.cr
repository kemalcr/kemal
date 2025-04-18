require "./spec_helper"
require "./handler_spec"

describe "Macros" do
  describe "#public_folder" do
    it "sets public folder" do
      public_folder "/some/path/to/folder"
      Kemal.config.public_folder.should eq("/some/path/to/folder")
    end
  end

  describe "#add_handler" do
    it "adds a custom handler" do
      add_handler CustomTestHandler.new
      Kemal.config.setup
      Kemal.config.handlers.size.should eq 7
    end
  end

  describe "#logging" do
    it "sets logging status" do
      logging false
      Kemal.config.logging.should eq false
    end
  end

  describe "#halt" do
    it "can break block with halt macro" do
      get "/non-breaking" do
        "hello"
        "world"
      end
      request = HTTP::Request.new("GET", "/non-breaking")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.body.should eq("world")

      get "/breaking" do |env|
        halt env, 404, "hello"
        "world"
      end
      request = HTTP::Request.new("GET", "/breaking")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(404)
      client_response.body.should eq("hello")
    end

    it "can break block with halt macro using default values" do
      get "/" do |env|
        halt env
        "world"
      end
      request = HTTP::Request.new("GET", "/")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.body.should eq("")
    end
  end

  describe "#callbacks" do
    it "can break block with halt macro from before_* callback" do
      filter_middleware = Kemal::FilterHandler.new
      filter_middleware._add_route_filter("GET", "/", :before) do |env|
        halt env, status_code: 400, response: "Missing origin."
      end

      get "/" do |_env|
        "Hello world"
      end

      request = HTTP::Request.new("GET", "/")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(400)
      client_response.body.should eq("Missing origin.")
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
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      request = HTTP::Request.new("GET", "/")
      response = call_request_on_app(request)
      response.status_code.should eq(200)

      response.headers["Content-Type"].should eq("application/octet-stream")
      response.headers["Content-Length"].should eq("18")
    end

    it "sends file with given path and given mime-type" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr", "image/jpeg"
      end

      request = HTTP::Request.new("GET", "/")
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.headers["Content-Type"].should eq("image/jpeg")
      response.headers["Content-Length"].should eq("18")
    end

    it "sends file with binary stream" do
      get "/" do |env|
        send_file env, "Serdar".to_slice
      end

      request = HTTP::Request.new("GET", "/")
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.headers["Content-Type"].should eq("application/octet-stream")
      response.headers["Content-Length"].should eq("6")
    end

    it "sends file with given path and given filename" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr", filename: "image.jpg"
      end

      request = HTTP::Request.new("GET", "/")
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.headers["Content-Disposition"].should eq("attachment; filename=\"image.jpg\"")
    end

    it "handles multiple range requests" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      headers = HTTP::Headers{"Range" => "bytes=0-4,7-11"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(206)
      response.headers["Content-Type"].should match(/^multipart\/byteranges; boundary=kemal-/)
      response.headers["Accept-Ranges"].should eq("bytes")

      # Verify multipart response structure
      body = response.body
      boundary = response.headers["Content-Type"].split("boundary=")[1]
      parts = body.split("--#{boundary}")
      # Parts structure:
      # 1. Empty part before first boundary
      # 2. First content part (0-4)
      # 3. Second content part (7-11)
      # 4. Trailing part after last boundary
      parts.size.should eq(4)

      # First part (0-4)
      first_part = parts[1]
      first_part.should contain("Content-Type: multipart/byteranges")
      first_part.should contain("Content-Range: bytes 0-4/18")
      first_part.split("\r\n\r\n")[1].strip.should eq("Hello")

      # Second part (7-11)
      second_part = parts[2]
      second_part.should contain("Content-Type: multipart/byteranges")
      second_part.should contain("Content-Range: bytes 7-11/18")
      second_part.split("\r\n\r\n")[1].strip.should eq("%= na")
    end

    it "handles invalid range requests" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      # Invalid range format
      headers = HTTP::Headers{"Range" => "invalid"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))

      # Range out of bounds
      headers = HTTP::Headers{"Range" => "bytes=100-200"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))

      # Invalid range values
      headers = HTTP::Headers{"Range" => "bytes=5-3"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))
    end

    it "handles empty range requests" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      headers = HTTP::Headers{"Range" => "bytes="}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))
    end

    it "handles overlapping ranges" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      headers = HTTP::Headers{"Range" => "bytes=0-5,3-8"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(206)
      response.headers["Content-Type"].should match(/^multipart\/byteranges; boundary=kemal-/)

      # Verify both ranges are included
      body = response.body
      boundary = response.headers["Content-Type"].split("boundary=")[1]
      parts = body.split("--#{boundary}")
      # Parts structure:
      # 1. Empty part before first boundary
      # 2. First content part (0-5)
      # 3. Second content part (3-8)
      # 4. Trailing part after last boundary
      parts.size.should eq(4)

      # First part (0-5)
      first_part = parts[1]
      first_part.should contain("Content-Range: bytes 0-5/18")
      first_part.split("\r\n\r\n")[1].strip.should eq("Hello")

      # Second part (3-8)
      second_part = parts[2]
      second_part.should contain("Content-Range: bytes 3-8/18")
      second_part.split("\r\n\r\n")[1].strip.should eq("lo <%=")
    end
  end

  describe "#gzip" do
    it "adds HTTP::CompressHandler to handlers" do
      gzip true
      Kemal.config.setup
      Kemal.config.handlers[4].should be_a(HTTP::CompressHandler)
    end
  end

  describe "#serve_static" do
    it "should disable static file hosting" do
      serve_static false
      Kemal.config.serve_static.should eq false
    end

    it "should enable gzip and dir_listing" do
      serve_static({"gzip" => true, "dir_listing" => true})
      conf = Kemal.config.serve_static
      conf.is_a?(Hash).should eq true
      if conf.is_a?(Hash)
        conf["gzip"].should eq true
        conf["dir_listing"].should eq true
      end
    end
  end
end
