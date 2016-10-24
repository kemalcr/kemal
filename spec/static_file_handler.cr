require "./spec_helper"

private def handle(request : HTTP::Request)
  handler_options = { :fallthrough => true }
  io = MemoryIO.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler = Kemal::StaticFileHandler.new "#{__DIR__}/static", handler_options
  handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io)
end

private def handle(request : HTTP::Request, fallthrough : Bool)
  handler_options = { :fallthrough => fallthrough }
  io = MemoryIO.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler = Kemal::StaticFileHandler.new "#{__DIR__}/static", handler_options
  handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io)
end

private def handle(request : HTTP::Request, handler_options : Hash(Symbol, Bool))
  io = MemoryIO.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler = Kemal::StaticFileHandler.new "#{__DIR__}/static", handler_options
  handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io)
end

private def handle(request : HTTP::Request, callback, handler_options = { :fallthrough => true })
  io = MemoryIO.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler = Kemal::StaticFileHandler.new "#{__DIR__}/static", handler_options
  handler.set_headers(callback)
  handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io)
end

describe Kemal::StaticFileHandler do
  file_text = File.read "#{__DIR__}/static/dir/test.txt"

  it "should serve a file with content type and etag" do
    response = handle HTTP::Request.new("GET", "/dir/test.txt")
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq "text/plain"
    response.headers["Etag"].should contain "W/\""
    response.body.should eq(File.read("#{__DIR__}/static/dir/test.txt"))
  end

  it "should respond with 304 if file has not changed" do
    response = handle HTTP::Request.new("GET", "/dir/test.txt")
    response.status_code.should eq(200)
    etag = response.headers["Etag"]

    headers = HTTP::Headers{"If-None-Match" => etag}
    response = handle HTTP::Request.new("GET", "/dir/test.txt", headers)
    response.status_code.should eq(304)
    response.body.should eq ""
  end

  it "should not list directory's entries" do
    serve_static({"gzip" => true, "dir_listing" => false})
    response = handle HTTP::Request.new("GET", "/dir/")
    response.status_code.should eq(404)
  end

  it "should list directory's entries when config is set" do
    response = handle(HTTP::Request.new("GET", "/dir/"), { :gzip => true, :dir_listing => true })
    response.status_code.should eq(200)
    response.body.should match(/test.txt/)
  end

  it "should gzip a file if config is true, headers accept gzip and file is > 880 bytes" do
    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    response = handle(HTTP::Request.new("GET", "/dir/bigger.txt", headers), { :gzip => true, :dir_listing => true })
    response.status_code.should eq(200)
    response.headers["Content-Encoding"].should eq "gzip"
  end

  it "should not gzip a file if config is true, headers accept gzip and file is < 880 bytes" do
    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    response = handle(HTTP::Request.new("GET", "/dir/test.txt", headers), { :gzip => true, :dir_listing => true  })
    response.status_code.should eq(200)
    response.headers["Content-Encoding"]?.should eq nil
  end

  it "should not gzip a file if config is false, headers accept gzip and file is > 880 bytes" do
    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    response = handle(HTTP::Request.new("GET", "/dir/bigger.txt", headers), { :gzip => false, :dir_listing => true })
    response.status_code.should eq(200)
    response.headers["Content-Encoding"]?.should eq nil
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
    %w(GET HEAD).each do |method|
      response = handle HTTP::Request.new(method, "/dir/test.txt")
      response.status_code.should eq(200)
    end

    %w(POST PUT DELETE).each do |method|
      response = handle HTTP::Request.new(method, "/dir/test.txt")
      response.status_code.should eq(404)
      response = handle HTTP::Request.new(method, "/dir/test.txt"), false
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

    response = handle(HTTP::Request.new("GET", "/dir/test.txt"), set_headers, { :fallthrough => false })
    response.headers.has_key?("Access-Control-Allow-Origin").should be_false

    response = handle(HTTP::Request.new("GET", "/dir/index.html"), set_headers, { :fallthrough => false })
    response.headers["Access-Control-Allow-Origin"].should eq("*")
  end
end
