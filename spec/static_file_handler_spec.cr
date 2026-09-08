require "./spec_helper"
require "file_utils"

private def handle(request, fallthrough = true, decompress = true, public_dir = "#{__DIR__}/static")
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler = Kemal::StaticFileHandler.new public_dir, fallthrough
  handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, decompress: decompress)
end

# Yields a public directory holding `app.js` next to a newer, pre-compressed `app.js.gz`,
# which is what `HTTP::StaticFileHandler` looks for when the client accepts gzip. Both files
# clear the 860 byte floor `send_file` compresses above, so a response that gets encoded
# twice shows up as one.
{% unless flag?(:without_zlib) %}
  private def with_precompressed_asset(&)
    dir = File.tempname("kemal-spec-static")
    Dir.mkdir_p(dir)
    source = Array.new(500) { |i| %(console.log("entry #{i}");) }.join("\n")
    previous_serve_static = Kemal.config.serve_static

    begin
      File.write(File.join(dir, "app.js"), source)
      File.open(File.join(dir, "app.js.gz"), "w") do |file|
        Compress::Gzip::Writer.open(file, &.print(source))
      end
      File.touch(File.join(dir, "app.js.gz"), Time.utc + 1.second)
      File.size(File.join(dir, "app.js.gz")).should be > 860

      serve_static({"gzip" => true, "dir_listing" => false})
      yield dir, source
    ensure
      Kemal.config.serve_static = previous_serve_static
      FileUtils.rm_rf(dir)
    end
  end
{% end %}

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

  {% unless flag?(:without_zlib) %}
    it "should gzip a file if config is true, headers accept gzip and file is > 880 bytes" do
      serve_static({"gzip" => true, "dir_listing" => true})
      headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
      response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
      response.status_code.should eq(200)
      response.headers["Content-Encoding"].should eq "gzip"
    end
  {% end %}

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

  {% unless flag?(:without_zlib) %}
    it "should advertise that the response was negotiated on Accept-Encoding" do
      serve_static({"gzip" => true, "dir_listing" => true})

      headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
      response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
      response.headers["Vary"].should eq "Accept-Encoding"

      # Also when this request happens to get the identity representation.
      response = handle HTTP::Request.new("GET", "/dir/bigger.txt")
      response.headers["Content-Encoding"]?.should be_nil
      response.headers["Vary"].should eq "Accept-Encoding"
    end

    it "should give the encoded variant an entity tag of its own" do
      serve_static({"gzip" => true, "dir_listing" => true})

      headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
      encoded = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
      encoded.headers["Content-Encoding"].should eq "gzip"
      encoded.headers["Etag"].should end_with %(-gzip")

      identity = handle HTTP::Request.new("GET", "/dir/bigger.txt")
      identity.headers["Etag"].should_not eq encoded.headers["Etag"]
      encoded.headers["Etag"].should eq Kemal::Utils.etag_with_coding(identity.headers["Etag"], "gzip")
    end

    it "should respond with 304 to the entity tag of the encoded variant" do
      serve_static({"gzip" => true, "dir_listing" => true})

      headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
      etag = (handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false).headers["Etag"]

      headers = HTTP::Headers{"Accept-Encoding" => "gzip", "If-None-Match" => etag}
      response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
      response.status_code.should eq(304)
      response.headers["Etag"].should eq etag
      response.body.should eq ""

      headers = HTTP::Headers{"Accept-Encoding" => "gzip", "If-None-Match" => %(W/"1-gzip")}
      response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
      response.status_code.should eq(200)
    end

    it "should not answer 304 with a variant the request would not have got" do
      serve_static({"gzip" => true, "dir_listing" => true})

      headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
      etag = (handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false).headers["Etag"]

      # The client holds the gzip variant but is now asking for the stored file, whose entity
      # tag is a different one. Answering 304 would pass its gzip copy off as this response.
      headers = HTTP::Headers{"Accept-Encoding" => "identity", "If-None-Match" => etag}
      response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
      response.status_code.should eq(200)
      response.headers["Content-Encoding"]?.should be_nil

      headers = HTTP::Headers{"Accept-Encoding" => "gzip", "If-None-Match" => etag.sub("-gzip", "-deflate")}
      response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
      response.status_code.should eq(200)
    end

    it "should tell a 304 apart on Accept-Encoding just like the 200 it stands for" do
      serve_static({"gzip" => true, "dir_listing" => true})

      headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
      response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
      etag = response.headers["Etag"]

      headers = HTTP::Headers{"Accept-Encoding" => "gzip", "If-None-Match" => etag}
      response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
      response.status_code.should eq(304)
      # RFC 9110 §15.4.5: a 304 sends the header fields its 200 would have.
      response.headers["Vary"].should eq "Accept-Encoding"
    end
  {% end %}

  {% if compare_versions(Crystal::VERSION, "1.17.0") >= 0 && !flag?(:without_zlib) %}
    it "should serve a pre-compressed file with the media type of the file it stands for" do
      with_precompressed_asset do |dir, source|
        headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
        response = handle HTTP::Request.new("GET", "/app.js", headers), decompress: false, public_dir: dir

        response.status_code.should eq(200)
        response.headers["Content-Encoding"].should eq "gzip"
        # The name on the wire is `app.js`; `app.js.gz` has no media type of its own.
        response.headers["Content-Type"].should eq MIME.from_filename("app.js")
        response.headers["Vary"].should eq "Accept-Encoding"
        response.headers["Etag"].should end_with %(-gzip")

        # Compressed once, by whoever wrote `app.js.gz` — not again on the way out.
        Compress::Gzip::Reader.open(IO::Memory.new(response.body), &.gets_to_end).should eq source
      end
    end

    it "should serve the original file when the client does not accept gzip" do
      with_precompressed_asset do |dir, source|
        response = handle HTTP::Request.new("GET", "/app.js"), decompress: false, public_dir: dir

        response.status_code.should eq(200)
        response.headers["Content-Encoding"]?.should be_nil
        response.headers["Content-Type"].should eq MIME.from_filename("app.js")
        response.headers["Vary"].should eq "Accept-Encoding"
        response.body.should eq source
      end
    end

    it "should not serve a pre-compressed file to a request that refused gzip" do
      with_precompressed_asset do |dir, source|
        # The stdlib matches `Accept-Encoding` by word and would send the `.gz` here.
        headers = HTTP::Headers{"Accept-Encoding" => "gzip;q=0"}
        response = handle HTTP::Request.new("GET", "/app.js", headers), decompress: false, public_dir: dir

        response.status_code.should eq(200)
        response.headers["Content-Encoding"]?.should be_nil
        response.body.should eq source
      end
    end

    it "should advertise the negotiation even with its own compression turned off" do
      with_precompressed_asset do |dir, _source|
        # The `.gz` neighbour is served whatever `serve_static` says about `gzip`, so the
        # URL is negotiated either way.
        serve_static({"gzip" => false, "dir_listing" => false})

        response = handle HTTP::Request.new("GET", "/app.js"), decompress: false, public_dir: dir
        response.headers["Content-Encoding"]?.should be_nil
        response.headers["Vary"].should eq "Accept-Encoding"

        headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
        response = handle HTTP::Request.new("GET", "/app.js", headers), decompress: false, public_dir: dir
        response.headers["Content-Encoding"].should eq "gzip"
        response.headers["Vary"].should eq "Accept-Encoding"
      end
    end

    it "should serve a range of a pre-compressed file from the variant it just served" do
      with_precompressed_asset do |dir, _source|
        # A resumed download asks for the rest of the representation it already has part
        # of, so the range has to come from the same file the full request answered with.
        headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
        full = handle HTTP::Request.new("GET", "/app.js", headers), decompress: false, public_dir: dir
        gz_size = full.body.bytesize

        headers = HTTP::Headers{"Accept-Encoding" => "gzip", "Range" => "bytes=0-9"}
        response = handle HTTP::Request.new("GET", "/app.js", headers), decompress: false, public_dir: dir

        response.status_code.should eq(206)
        response.headers["Content-Encoding"].should eq "gzip"
        response.headers["Content-Range"].should eq "bytes 0-9/#{gz_size}"
        # Bytes, not characters: the gzip header carries a timestamp that differs per
        # run, and when those bytes happen to form multibyte sequences a `String`
        # slice of ten characters is not ten bytes.
        response.body.to_slice.should eq full.body.to_slice[0, 10]
        response.headers["Etag"].should end_with %(-gzip")
      end
    end

    it "should decline a multi-range request for an encoded representation" do
      with_precompressed_asset do |dir, source|
        # The `multipart/byteranges` envelope holding the parts is not itself gzip, so it
        # cannot go out under the `Content-Encoding` the parts were taken from.
        headers = HTTP::Headers{"Accept-Encoding" => "gzip", "Range" => "bytes=0-9,20-29"}
        response = handle HTTP::Request.new("GET", "/app.js", headers), decompress: false, public_dir: dir

        response.status_code.should eq(200)
        response.headers["Content-Encoding"].should eq "gzip"
        response.headers.has_key?("Content-Range").should be_false
        Compress::Gzip::Reader.open(IO::Memory.new(response.body), &.gets_to_end).should eq source
      end
    end

    it "should keep the entity tag of every variant of a pre-compressed file matchable" do
      with_precompressed_asset do |dir, _source|
        # The neighbour stands in only where gzip is the coding the request would get
        # anyway; a client that prefers deflate gets deflate, compressed on the fly. Either
        # way the tag on the 200 is the one the next revalidation is answered against.
        {"gzip" => "gzip", "deflate, gzip;q=0.5" => "deflate"}.each do |accept, expected|
          headers = HTTP::Headers{"Accept-Encoding" => accept}
          response = handle HTTP::Request.new("GET", "/app.js", headers), decompress: false, public_dir: dir
          response.headers["Content-Encoding"].should eq expected
          etag = response.headers["Etag"]
          etag.should end_with %(-#{expected}")

          headers = HTTP::Headers{"Accept-Encoding" => accept, "If-None-Match" => etag}
          response = handle HTTP::Request.new("GET", "/app.js", headers), decompress: false, public_dir: dir
          response.status_code.should eq(304)
          response.headers["Etag"].should eq etag
        end
      end
    end

    it "should serve a pre-compressed index.html" do
      with_precompressed_asset do |dir, _source|
        source = File.read(File.join(dir, "app.js"))
        File.write(File.join(dir, "index.html"), source)
        File.open(File.join(dir, "index.html.gz"), "w") do |file|
          Compress::Gzip::Writer.open(file, &.print(source))
        end
        File.touch(File.join(dir, "index.html.gz"), Time.utc + 1.second)
        serve_static({"gzip" => true, "dir_index" => true, "dir_listing" => false})

        headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
        response = handle HTTP::Request.new("GET", "/", headers), decompress: false, public_dir: dir

        response.status_code.should eq(200)
        response.headers["Content-Encoding"].should eq "gzip"
        response.headers["Content-Type"].should eq MIME.from_filename("index.html")
        Compress::Gzip::Reader.open(IO::Memory.new(response.body), &.gets_to_end).should eq source
      end
    end
  {% end %}

  {% unless flag?(:without_zlib) %}
    it "should not confirm the stored file's tag for an encoded response" do
      serve_static({"gzip" => true, "dir_listing" => true})

      # The client holds the identity copy while gzip is what this request is answered with,
      # so its validator is not the selected representation's (RFC 9110 §13.1.2).
      identity_etag = (handle HTTP::Request.new("GET", "/dir/bigger.txt")).headers["Etag"]

      headers = HTTP::Headers{"Accept-Encoding" => "gzip", "If-None-Match" => identity_etag}
      response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
      response.status_code.should eq(200)
      response.headers["Content-Encoding"].should eq "gzip"

      # And with no coding in play it still matches.
      headers = HTTP::Headers{"If-None-Match" => identity_etag}
      response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers)
      response.status_code.should eq(304)
    end
  {% end %}

  it "should not confirm an encoded variant of a file it never encodes" do
    serve_static({"gzip" => false, "dir_listing" => true})

    etag = (handle HTTP::Request.new("GET", "/dir/bigger.txt")).headers["Etag"]

    headers = HTTP::Headers{"Accept-Encoding" => "gzip", "If-None-Match" => Kemal::Utils.etag_with_coding(etag, "gzip")}
    response = handle HTTP::Request.new("GET", "/dir/bigger.txt", headers), decompress: false
    response.status_code.should eq(200)
  end

  it "should not serve a not found file" do
    response = handle HTTP::Request.new("GET", "/not_found_file.txt")
    response.status_code.should eq(404)
  end

  it "should report a file it cannot read as not found" do
    dir = File.tempname("kemal-spec-unreadable")
    Dir.mkdir_p(dir)
    path = File.join(dir, "private.txt")
    File.write(path, "secret")
    File.chmod(path, 0o000)

    begin
      # Root, and Windows, read a mode-000 file regardless; there is nothing to
      # test on such a box.
      pending!("this process can read a file with no permission bits") if File.readable?(path)

      response = handle HTTP::Request.new("GET", "/private.txt"), public_dir: dir

      # The same answer a missing file gets: nothing about the file - not its
      # path, not its validators - reaches the client.
      response.status_code.should eq(404)
      response.body.should_not contain("secret")
      response.body.should_not contain(path)
      response.headers["Etag"]?.should be_nil
      response.headers["Last-Modified"]?.should be_nil
    ensure
      File.chmod(path, 0o600)
      FileUtils.rm_rf(dir)
    end
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

    %w[POST PUT DELETE QUERY].each do |method|
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
    # A directory path answers with its listing, which is off by default.
    serve_static({"gzip" => true, "dir_listing" => true})
    response = handle HTTP::Request.new("GET", "/dir/nested/path/")
    response.status_code.should eq(200)
  end
end
