require "./spec_helper"

{% if flag?(:linux) %}
  # Bytes this process has read, per the kernel.
  private def process_read_bytes : Int64
    File.read("/proc/self/io").lines.find!(&.starts_with?("rchar")).split(':')[1].strip.to_i64
  end
{% end %}

describe "Kemal::HeadRequestHandler" do
  it "implicitly handles GET endpoints, with Content-Length header" do
    get "/" do
      "hello"
    end
    request = HTTP::Request.new("HEAD", "/")
    client_response = call_request_on_app(request)
    client_response.body.should eq("")
    client_response.headers["Content-Length"].should eq("5")
  end

  it "answers HEAD on a file from its size without producing the body" do
    path = File.tempname("kemal-spec-head", ".bin")
    File.open(path, "w", &.truncate(4 * 1024 * 1024))

    begin
      get "/file" do |env|
        send_file env, path
      end
      client_response = call_request_on_app(HTTP::Request.new("HEAD", "/file"))
      client_response.status_code.should eq(200)
      client_response.body.should eq("")
      client_response.headers["Content-Length"].should eq((4 * 1024 * 1024).to_s)
    ensure
      File.delete(path)
    end
  end

  {% if flag?(:linux) %}
    it "does not read the file to answer HEAD" do
      # `HeadRequestHandler` learns the length by producing the body into a
      # counting sink; for stored bytes going out as they are, the length is
      # the file's and the read is pure waste. Counted through `/proc/self/io`.
      path = File.tempname("kemal-spec-head", ".bin")
      File.open(path, "w", &.truncate(4 * 1024 * 1024))

      begin
        get "/file" do |env|
          send_file env, path
        end
        call_request_on_app(HTTP::Request.new("GET", "/file")) # warm every cache but the file's

        before = process_read_bytes
        call_request_on_app(HTTP::Request.new("HEAD", "/file")).status_code.should eq(200)
        (process_read_bytes - before).should be < 1024 * 1024
      ensure
        File.delete(path)
      end
    end
  {% end %}

  it "prefers explicit HEAD endpoint if specified" do
    Kemal::RouteHandler::INSTANCE.add_route("HEAD", "/") { "hello" }
    get "/" do
      raise "shouldn't be called!"
    end
    request = HTTP::Request.new("HEAD", "/")
    client_response = call_request_on_app(request)
    client_response.body.should eq("")
    client_response.headers["Content-Length"].should eq("5")
  end

  {% unless flag?(:without_zlib) %}
    it "gives compressed Content-Length when gzip enabled" do
      gzip true
      get "/" do
        "hello"
      end
      headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
      request = HTTP::Request.new("HEAD", "/", headers)
      client_response = call_request_on_app(request)
      client_response.body.should eq("")
      client_response.headers["Content-Encoding"].should eq("gzip")
      client_response.headers["Content-Length"].should eq("25")
    end
  {% end %}

  it "counts a body larger than Int32::MAX" do
    get "/" do |env|
      # 2048 MiB = Int32::MAX + 1. `NullIO` only counts, so nothing is allocated
      # per write and no file is needed.
      chunk = Bytes.new(1024 * 1024)
      2048.times { env.response.write(chunk) }
      ""
    end
    request = HTTP::Request.new("HEAD", "/")
    client_response = call_request_on_app(request)
    client_response.body.should eq("")
    client_response.headers["Content-Length"].should eq("2147483648")
  end
end
