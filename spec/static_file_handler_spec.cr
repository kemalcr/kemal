require "./spec_helper"

private def handle(request, fallthrough = true, decompress = true, public_dir = "#{__DIR__}/static", handler : Kemal::StaticFileHandler? = nil)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler ||= Kemal::StaticFileHandler.new public_dir, fallthrough
  handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, decompress: decompress)
end

describe Kemal::StaticFileHandler do
  file = File.open "#{__DIR__}/static/dir/test.txt"
  File.open "#{__DIR__}/static/dir/nested/path/test.txt"
  file_size = file.size

  it "should serve a file with content type and etag" do
    response = handle HTTP::Request.new("GET", "/dir/test.txt")
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq "text/plain"
    response.headers["Etag"].should contain "W/\""
    response.body.should eq(File.read("#{__DIR__}/static/dir/test.txt"))
  end

  it "should serve the 'index.html' file when a directory is requested and index serving is enabled" do
    serve_static({"dir_index" => true})
    response = handle HTTP::Request.new("GET", "/dir/")
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq "text/html"
    response.headers["Etag"].should contain "W/\""
    response.body.should eq(File.read("#{__DIR__}/static/dir/index.html"))
  end

  it "should respond with 304 if file has not changed" do
    response = handle HTTP::Request.new("GET", "/dir/test.txt")
    response.status_code.should eq(200)
    etag = response.headers["Etag"]

    headers = HTTP::Headers{"If-None-Match" => etag}
    response = handle HTTP::Request.new("GET", "/dir/test.txt", headers)
    response.headers["Content-Type"]?.should be_nil
    response.status_code.should eq(304)
    response.body.should eq ""
  end

  it "should not list directory's entries" do
    serve_static({"gzip" => true, "dir_listing" => false})
    response = handle HTTP::Request.new("GET", "/dir/")
    response.status_code.should eq(404)
  end

  it "should list directory's entries when config is set" do
    serve_static({"gzip" => true, "dir_listing" => true})
    response = handle HTTP::Request.new("GET", "/dir/")
    response.status_code.should eq(200)
    response.body.should match(/test.txt/)
  end

  it "should gzip a file if config is true, headers accept gzip and file is > 880 bytes" do
    serve_static({"gzip" => true, "dir_listing" => true})
    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
    response.status_code.should eq(200)
    response.headers["Content-Encoding"].should eq "gzip"
  end

  it "should not gzip a file if config is true, headers accept gzip and file is < 880 bytes" do
    serve_static({"gzip" => true, "dir_listing" => true})
    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    response = handle HTTP::Request.new("GET", "/dir/test.txt", headers), decompress: false
    response.status_code.should eq(200)
    response.headers["Content-Encoding"]?.should be_nil
  end

  it "should not gzip a file if config is false, headers accept gzip and file is > 880 bytes" do
    serve_static({"gzip" => false, "dir_listing" => true})
    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
    response.status_code.should eq(200)
    response.headers["Content-Encoding"]?.should be_nil
  end

  it "should not serve a not found file" do
    response = handle HTTP::Request.new("GET", "/not_found_file.txt")
    response.status_code.should eq(404)
  end

  it "should not serve a not found directory" do
    response = handle HTTP::Request.new("GET", "/not_found_dir/")
    response.status_code.should eq(404)
  end

  it "should not serve a file as directory" do
    response = handle HTTP::Request.new("GET", "/dir/test.txt/")
    response.status_code.should eq(404)
  end

  it "should handle only GET and HEAD method" do
    %w[GET HEAD].each do |method|
      response = handle HTTP::Request.new(method, "/dir/test.txt")
      response.status_code.should eq(200)
    end

    %w[POST PUT DELETE].each do |method|
      response = handle HTTP::Request.new(method, "/dir/test.txt")
      response.status_code.should eq(404)
      response = handle HTTP::Request.new(method, "/dir/test.txt"), false
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET, HEAD")
    end
  end

  it "should send part of files when requested (RFC7233)" do
    %w[POST PUT DELETE HEAD].each do |method|
      headers = HTTP::Headers{"Range" => "bytes=0-4"}
      response = handle HTTP::Request.new(method, "/dir/test.txt", headers)
      response.status_code.should_not eq(206)
      response.headers.has_key?("Content-Range").should be_false
    end

    %w[GET].each do |method|
      headers = HTTP::Headers{"Range" => "bytes=0-4"}
      response = handle HTTP::Request.new(method, "/dir/test.txt", headers)
      response.status_code.should eq(206)
      response.headers.has_key?("Content-Range").should be_true
      match = response.headers["Content-Range"].match(/bytes (\d+)-(\d+)\/(\d+)/)
      match.should_not be_nil
      if match
        start_range = match[1].to_i { 0 }
        end_range = match[2].to_i { 0 }
        range_size = match[3].to_i { 0 }

        range_size.should eq file_size
        (end_range < file_size).should be_true
        (start_range < end_range).should be_true
      end
    end
  end

  it "should serve byte ranges from the in-memory cache" do
    serve_static({"gzip" => false, "dir_listing" => true, "cache" => true, "cache_size" => 1024})
    headers = HTTP::Headers{"Range" => "bytes=0-4"}
    response = handle HTTP::Request.new("GET", "/dir/test.txt", headers)

    response.status_code.should eq(206)
    response.headers["Content-Range"].should eq("bytes 0-4/#{file_size}")
    response.body.should eq(File.read("#{__DIR__}/static/dir/test.txt")[0, 5])
  end

  it "should invalidate cached files when the source file changes" do
    serve_static({"gzip" => false, "dir_listing" => false, "cache" => true, "cache_size" => 1024, "cache_check_interval" => 10})
    temp_dir = File.tempname("kemal-static-cache")
    Dir.mkdir(temp_dir)

    begin
      handler = Kemal::StaticFileHandler.new temp_dir
      file_path = File.join(temp_dir, "test.txt")
      File.write(file_path, "first version")

      response = handle HTTP::Request.new("GET", "/test.txt"), public_dir: temp_dir, handler: handler
      response.status_code.should eq(200)
      response.body.should eq("first version")

      File.write(file_path, "second version")

      sleep 20.milliseconds

      response = handle HTTP::Request.new("GET", "/test.txt"), public_dir: temp_dir, handler: handler
      response.status_code.should eq(200)
      response.body.should eq("second version")
    ensure
      File.delete?(File.join(temp_dir, "test.txt"))
      Dir.delete(temp_dir)
    end
  end

  it "should defer metadata revalidation until the interval elapses" do
    serve_static({"gzip" => false, "dir_listing" => false, "cache" => true, "cache_size" => 1024, "cache_check_interval" => 50})
    temp_dir = File.tempname("kemal-static-cache-window")
    Dir.mkdir(temp_dir)

    begin
      handler = Kemal::StaticFileHandler.new temp_dir
      file_path = File.join(temp_dir, "test.txt")
      File.write(file_path, "first version")

      response = handle HTTP::Request.new("GET", "/test.txt"), public_dir: temp_dir, handler: handler
      response.status_code.should eq(200)
      response.body.should eq("first version")

      File.write(file_path, "second version now")

      response = handle HTTP::Request.new("GET", "/test.txt"), public_dir: temp_dir, handler: handler
      response.status_code.should eq(200)
      response.body.should eq("first version")

      sleep 60.milliseconds

      response = handle HTTP::Request.new("GET", "/test.txt"), public_dir: temp_dir, handler: handler
      response.status_code.should eq(200)
      response.body.should eq("second version now")
    ensure
      File.delete?(File.join(temp_dir, "test.txt"))
      Dir.delete(temp_dir)
    end
  end

  it "should handle setting custom headers" do
    headers = Proc(HTTP::Server::Context, String, File::Info, Nil).new do |env, path, stat|
      if path =~ /\.html$/
        env.response.headers.add("Access-Control-Allow-Origin", "*")
      end
      env.response.headers.add("Content-Size", stat.size.to_s)
    end

    static_headers(&headers)

    response = handle HTTP::Request.new("GET", "/dir/test.txt")
    response.headers.has_key?("Access-Control-Allow-Origin").should be_false
    response.headers["Content-Size"].should eq(
      File.info("#{__DIR__}/static/dir/test.txt").size.to_s
    )

    response = handle HTTP::Request.new("GET", "/dir/index.html")
    response.headers["Access-Control-Allow-Origin"].should eq("*")
  end

  # Path Traversal Security Tests
  it "should prevent path traversal attacks with .." do
    response = handle HTTP::Request.new("GET", "/../../../etc/passwd")
    response.status_code.should eq(302)
  end

  it "should prevent path traversal attacks with URL encoded .." do
    response = handle HTTP::Request.new("GET", "/..%2f..%2f..%2fetc%2fpasswd")
    response.status_code.should eq(302)
  end

  it "should prevent path traversal attacks with mixed .. and URL encoded .." do
    response = handle HTTP::Request.new("GET", "/..%2f../..%2fetc%2fpasswd")
    response.status_code.should eq(302)
  end

  it "should allow legitimate nested paths" do
    response = handle HTTP::Request.new("GET", "/dir/nested/path/test.txt")
    response.status_code.should eq(200)
  end

  it "should handle requests with trailing slashes in nested paths" do
    serve_static({"gzip" => true, "dir_listing" => true})
    response = handle HTTP::Request.new("GET", "/dir/nested/path/")
    response.status_code.should eq(200)
  end
end
