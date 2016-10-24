require "./spec_helper"

private def get_handler
  Kemal::StaticFileHandler.new("#{__DIR__}/static", { :fallthrough => true })
end

private def get_handler(options : Hash(Symbol, Bool))
  Kemal::StaticFileHandler.new("#{__DIR__}/static", options)
end

private def handle(request : HTTP::Request, handler : Kemal::StaticFileHandler)
  io = MemoryIO.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io)
end

describe Kemal::StaticFileHandler do
  file_text = File.read "#{__DIR__}/static/dir/test.txt"

  it "should serve a file with content type and etag" do
    handler = get_handler
    response = handle HTTP::Request.new("GET", "/dir/test.txt"), handler
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq "text/plain"
    response.headers["Etag"].should contain "W/\""
    response.body.should eq(File.read("#{__DIR__}/static/dir/test.txt"))
  end

  it "should respond with 304 if file has not changed" do
    handler = get_handler
    response = handle HTTP::Request.new("GET", "/dir/test.txt"), handler
    response.status_code.should eq(200)
    etag = response.headers["Etag"]

    headers = HTTP::Headers{"If-None-Match" => etag}
    response = handle HTTP::Request.new("GET", "/dir/test.txt", headers), handler
    response.status_code.should eq(304)
    response.body.should eq ""
  end

  it "should not list directory's entries" do
    handler = get_handler({ :gzip => true, :dir_listing => false })

    response = handle HTTP::Request.new("GET", "/dir/"), handler
    response.status_code.should eq(404)
  end

  it "should list directory's entries when config is set" do
    handler = get_handler({ :gzip => true, :dir_listing => true })
    response = handle HTTP::Request.new("GET", "/dir/"), handler
    response.status_code.should eq(200)
    response.body.should match(/test.txt/)
  end

  it "should gzip a file if config is true, headers accept gzip and file is > 880 bytes" do
    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    handler = get_handler({ :gzip => true, :dir_listing => true })
    response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), handler
    response.status_code.should eq(200)
    response.headers["Content-Encoding"].should eq "gzip"
  end

  it "should not gzip a file if config is true, headers accept gzip and file is < 880 bytes" do
    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    handler = get_handler({ :gzip => true, :dir_listing => true })
    response = handle HTTP::Request.new("GET", "/dir/test.txt", headers), handler
    response.status_code.should eq(200)
    response.headers["Content-Encoding"]?.should eq nil
  end

  it "should not gzip a file if config is false, headers accept gzip and file is > 880 bytes" do
    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    handler = get_handler({ :gzip => false, :dir_listing => true })
    response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), handler
    response.status_code.should eq(200)
    response.headers["Content-Encoding"]?.should eq nil
  end

  it "should not serve a not found file" do
    response = handle HTTP::Request.new("GET", "/not_found_file.txt"), get_handler
    response.status_code.should eq(404)
  end

  it "should not serve a not found directory" do
    response = handle HTTP::Request.new("GET", "/not_found_dir/"), get_handler
    response.status_code.should eq(404)
  end

  it "should not serve a file as directory" do
    response = handle HTTP::Request.new("GET", "/dir/test.txt/"), get_handler
    response.status_code.should eq(404)
  end

  it "should handle only GET and HEAD method" do
    %w(GET HEAD).each do |method|
      response = handle HTTP::Request.new(method, "/dir/test.txt"), get_handler
      response.status_code.should eq(200)
    end

    %w(POST PUT DELETE).each do |method|
      response = handle HTTP::Request.new(method, "/dir/test.txt"), get_handler
      response.status_code.should eq(404)
      response = handle HTTP::Request.new(method, "/dir/test.txt"), get_handler({ :fallthrough => false })
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET, HEAD")
    end
  end

  it "should handle setting custom headers" do
    set_headers = Proc(HTTP::Server::Response, String, File::Stat, Void).new do |response, path, stat|
      if path =~ /\.html$/
        response.headers.add("Access-Control-Allow-Origin", "*")
      end
    end
    handler = get_handler({ :fallthrough => false })
    handler.set_headers(set_headers)

    response = handle HTTP::Request.new("GET", "/dir/test.txt"), handler
    response.headers.has_key?("Access-Control-Allow-Origin").should be_false

    response = handle HTTP::Request.new("GET", "/dir/index.html"), handler
    response.headers["Access-Control-Allow-Origin"].should eq("*")
  end
end
