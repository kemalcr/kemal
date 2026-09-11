require "./spec_helper"
require "./handler_spec"

# Yields the path of a file `send_file` compresses: an extension in `Kemal::Utils::ZIP_TYPES`
# and a size above the 860 byte floor, served with the `gzip` option of `serve_static` on.
private def with_compressible_file(&)
  path = File.tempname("kemal-spec", ".js")
  File.write(path, "var x = 1;\n" * 1000)
  previous_serve_static = Kemal.config.serve_static

  begin
    serve_static({"gzip" => true})
    yield path
  ensure
    Kemal.config.serve_static = previous_serve_static
    File.delete(path)
  end
end

describe "Macros" do
  describe "#public_folder" do
    it "sets public folder" do
      public_folder "/some/path/to/folder"
      Kemal.config.public_folder.should eq("/some/path/to/folder")
    end
  end

  describe "#use" do
    it "adds a custom handler" do
      use CustomTestHandler.new
      Kemal.config.setup
      Kemal.config.handlers.size.should eq 8
    end
  end

  describe "#logging" do
    it "sets logging status" do
      logging false
      Kemal.config.logging.should be_false
    end
  end

  describe "#halt" do
    it "can break block with halt macro" do
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

    it "halts with chained status/json" do
      get "/halt-status-json" do |env|
        halt env.status(500).json({error: "Something went wrong"})
        "should-not-render"
      end

      request = HTTP::Request.new("GET", "/halt-status-json")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(500)
      client_response.headers["Content-Type"].should eq("application/json")
      client_response.body.should eq(%({"error":"Something went wrong"}))
    end

    it "halts with chained json" do
      get "/halt-json" do |env|
        halt env.json({error: "Something went wrong"})
        "should-not-render"
      end

      request = HTTP::Request.new("GET", "/halt-json")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.headers["Content-Type"].should eq("application/json")
      client_response.body.should eq(%({"error":"Something went wrong"}))
    end

    it "writes body when halting with chained json" do
      get "/halt-json-raw" do |env|
        halt env.status(500).json({error: "Something went wrong"})
        "should-not-render"
      end

      request = HTTP::Request.new("GET", "/halt-json-raw")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(500)
      client_response.headers["Content-Type"].should eq("application/json")
      client_response.body.should eq(%({"error":"Something went wrong"}))
    end

    it "halts env" do
      get "/halt-env" do |env|
        env.response.status_code = 500
        env.response.content_type = "application/json"
        env.response.print({error: "Something went wrong"}.to_json)
        halt env
        "should-not-render"
      end

      request = HTTP::Request.new("GET", "/halt-env")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(500)
      client_response.headers["Content-Type"].should eq("application/json")
      client_response.body.should eq(%({"error":"Something went wrong"}))
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

    it "writes body when halting with chained json in before filter" do
      filter_middleware = Kemal::FilterHandler.new
      filter_middleware._add_route_filter("GET", "/halt-json-filter", :before) do |env|
        halt env.status(500).json({error: "Something went wrong"})
      end

      get "/halt-json-filter" do |_env|
        "should-not-render"
      end

      request = HTTP::Request.new("GET", "/halt-json-filter")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(500)
      client_response.headers["Content-Type"].should eq("application/json")
      client_response.body.should eq(%({"error":"Something went wrong"}))
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

    it "sends a non-ASCII filename as an RFC 8187 filename* with an ASCII fallback" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr", filename: "rapor ünlü.pdf"
      end
      response = call_request_on_app(HTTP::Request.new("GET", "/"))
      response.status_code.should eq(200)
      response.headers["Content-Disposition"].should eq(%(attachment; filename="rapor _nl_.pdf"; filename*=UTF-8''rapor%20%C3%BCnl%C3%BC.pdf))
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

      # First part (0-4). Each part carries the media type of the representation itself,
      # not the multipart/byteranges type of the enclosing response.
      first_part = parts[1]
      first_part.should contain("Content-Type: application/octet-stream")
      first_part.should contain("Content-Range: bytes 0-4/18")
      first_part.split("\r\n\r\n")[1].strip.should eq("Hello")

      # Second part (7-11)
      second_part = parts[2]
      second_part.should contain("Content-Type: application/octet-stream")
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

      # A last-pos below the first-pos makes the range set invalid (RFC 9110 §14.1.2),
      # and an invalid Range header is ignored (§14.1.1)
      headers = HTTP::Headers{"Range" => "bytes=5-3"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))

      # Not a byte-range-spec
      headers = HTTP::Headers{"Range" => "bytes=abc"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))

      # Range units other than bytes are not supported and therefore ignored
      headers = HTTP::Headers{"Range" => "items=0-4"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)
      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))
    end

    # The 18 byte fixture reads "Hello <%= name %>\n"; the cases below follow RFC 9110 §14.1.2.
    it "serves a single byte range" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      {"bytes=0-0" => {"0-0", "H"}, "bytes=5-5" => {"5-5", " "}}.each do |range, (content_range, body)|
        headers = HTTP::Headers{"Range" => range}
        request = HTTP::Request.new("GET", "/", headers)
        response = call_request_on_app(request)

        response.status_code.should eq(206)
        response.headers["Content-Range"].should eq("bytes #{content_range}/18")
        response.headers["Content-Length"].should eq("1")
        response.body.should eq(body)
      end
    end

    it "serves an open-ended range up to the last byte" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      headers = HTTP::Headers{"Range" => "bytes=17-"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(206)
      response.headers["Content-Range"].should eq("bytes 17-17/18")
      response.body.should eq("\n")
    end

    it "clamps a last-pos beyond the end of the file" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      headers = HTTP::Headers{"Range" => "bytes=0-99999"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(206)
      response.headers["Content-Range"].should eq("bytes 0-17/18")
      response.headers["Content-Length"].should eq("18")
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))
    end

    it "serves a suffix range" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      headers = HTTP::Headers{"Range" => "bytes=-5"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(206)
      response.headers["Content-Range"].should eq("bytes 13-17/18")
      response.body.should eq("e %>\n")

      # A suffix longer than the file selects the whole file
      headers = HTTP::Headers{"Range" => "bytes=-100"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(206)
      response.headers["Content-Range"].should eq("bytes 0-17/18")
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))
    end

    it "responds with 416 when no range is satisfiable" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      # A first-pos at or beyond the end, and a zero suffix-length, are unsatisfiable
      ["bytes=100-200", "bytes=18-", "bytes=-0", "bytes=100-200,300-"].each do |range|
        headers = HTTP::Headers{"Range" => range}
        request = HTTP::Request.new("GET", "/", headers)
        response = call_request_on_app(request)

        response.status_code.should eq(416)
        response.headers["Content-Range"].should eq("bytes */18")
        response.body.should eq("")
      end
    end

    it "drops unsatisfiable ranges when at least one range is satisfiable" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      headers = HTTP::Headers{"Range" => "bytes=100-200,0-4"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(206)
      response.headers["Content-Range"].should eq("bytes 0-4/18")
      response.body.should eq("Hello")
    end

    it "treats a byte position that overflows Int64 as beyond the end of the file" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      # Used to be parsed as 0 and served the whole file as a 206
      headers = HTTP::Headers{"Range" => "bytes=99999999999999999999-"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(416)
      response.headers["Content-Range"].should eq("bytes */18")

      headers = HTTP::Headers{"Range" => "bytes=0-99999999999999999999"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(206)
      response.headers["Content-Range"].should eq("bytes 0-17/18")
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))
    end

    it "serves every range of a multi-range request" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      # The second range used to be dropped silently, leaving a single-range 206
      headers = HTTP::Headers{"Range" => "bytes=0-4, 7-7"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(206)
      boundary = response.headers["Content-Type"].split("boundary=")[1]
      parts = response.body.split("--#{boundary}")
      parts.size.should eq(4)

      parts[1].should contain("Content-Range: bytes 0-4/18")
      parts[1].split("\r\n\r\n")[1].strip.should eq("Hello")

      parts[2].should contain("Content-Range: bytes 7-7/18")
      parts[2].split("\r\n\r\n")[1].strip.should eq("%")
    end

    it "ignores empty list elements" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      # RFC 9110 §5.6.1.2: a recipient must ignore empty list elements
      ["bytes=0-4,", "bytes=,0-4", "bytes=0-4,,7-7"].each do |range|
        headers = HTTP::Headers{"Range" => range}
        request = HTTP::Request.new("GET", "/", headers)
        response = call_request_on_app(request)

        response.status_code.should eq(206)
      end

      headers = HTTP::Headers{"Range" => "bytes=0-4,"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)
      response.headers["Content-Range"].should eq("bytes 0-4/18")
      response.body.should eq("Hello")

      headers = HTTP::Headers{"Range" => "bytes=0-4,,7-7"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)
      boundary = response.headers["Content-Type"].split("boundary=")[1]
      response.body.split("--#{boundary}").size.should eq(4)
    end

    it "accepts the bytes range unit case-insensitively" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      headers = HTTP::Headers{"Range" => "Bytes=0-4"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(206)
      response.headers["Content-Range"].should eq("bytes 0-4/18")
    end

    it "ignores Range on HEAD requests" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      headers = HTTP::Headers{"Range" => "bytes=100-200"}
      request = HTTP::Request.new("HEAD", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(200)
      response.headers.has_key?("Content-Range").should be_false
      response.headers["Content-Length"].should eq("18")
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

    it "ignores range sets asking for more bytes than the file holds" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      # Each open-ended range expands to the whole file, so 2000 of them used to produce
      # 2000 copies of it from a single request. The byte budget rejects this at the
      # second range; the range count is covered separately below.
      headers = HTTP::Headers{"Range" => "bytes=" + Array.new(2000, "0-").join(",")}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))
    end

    it "ignores many small ranges that stay within the byte budget" do
      # Small ranges never exhaust the byte budget on a large enough file, so only the
      # range count stops them. Each part still costs a seek plus its multipart framing.
      path = File.tempname("kemal-spec", ".txt")
      File.write(path, "a" * 8192)

      begin
        get "/" do |env|
          send_file env, path
        end

        ranges = (0...2000).map { |i| "#{i * 2}-#{i * 2 + 1}" }
        headers = HTTP::Headers{"Range" => "bytes=#{ranges.join(",")}"}
        request = HTTP::Request.new("GET", "/", headers)
        response = call_request_on_app(request)

        response.status_code.should eq(200)
        response.body.bytesize.should eq(8192)
      ensure
        File.delete(path)
      end
    end

    {% unless flag?(:without_zlib) %}
      it "compresses the full response it falls back to when a range set is refused" do
        # The fallback must cost no more than a plain GET of the same URL. Serving it
        # uncompressed would let a two-range header defeat compression on every request.
        path = File.tempname("kemal-spec", ".js")
        File.write(path, "var x = 1;\n" * 1000)
        previous_serve_static = Kemal.config.serve_static

        begin
          serve_static({"gzip" => true})

          get "/" do |env|
            send_file env, path
          end

          headers = HTTP::Headers{"Range" => "bytes=0-,0-", "Accept-Encoding" => "gzip"}
          request = HTTP::Request.new("GET", "/", headers)
          response = call_request_on_app(request)

          response.status_code.should eq(200)
          response.headers["Content-Encoding"].should eq("gzip")
          response.body.bytesize.should be < File.size(path)
        ensure
          Kemal.config.serve_static = previous_serve_static
          File.delete(path)
        end
      end
    {% end %}

    it "ignores range sets that overlap into more bytes than the file holds" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      # 0-9 and 5-17 overlap and together cover 23 bytes of an 18 byte file.
      headers = HTTP::Headers{"Range" => "bytes=0-9,5-17"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))
    end

    it "serves a range set that is exactly at the range limit" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/layout_with_yield_and_vars.ecr"
      end

      ranges = (0...Kemal.config.max_ranges).map { |i| "#{i * 2}-#{i * 2 + 1}" }
      headers = HTTP::Headers{"Range" => "bytes=#{ranges.join(",")}"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(206)
      boundary = response.headers["Content-Type"].split("boundary=")[1]
      # One empty part before the first boundary and one trailing part after the last.
      response.body.split("--#{boundary}").size.should eq(Kemal.config.max_ranges + 2)
    end

    it "ignores range sets with more ranges than `max_ranges`" do
      get "/" do |env|
        send_file env, "#{__DIR__}/asset/layout_with_yield_and_vars.ecr"
      end

      ranges = (0..Kemal.config.max_ranges).map { |i| "#{i * 2}-#{i * 2 + 1}" }
      headers = HTTP::Headers{"Range" => "bytes=#{ranges.join(",")}"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/asset/layout_with_yield_and_vars.ecr"))
    end

    it "honors a custom `max_ranges`" do
      Kemal.config.max_ranges = 1

      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      headers = HTTP::Headers{"Range" => "bytes=0-4,7-11"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(200)
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))
    end

    it "advertises `Accept-Ranges: none` when ranges are disabled" do
      Kemal.config.max_ranges = 0

      get "/" do |env|
        send_file env, "#{__DIR__}/asset/hello.ecr"
      end

      headers = HTTP::Headers{"Range" => "bytes=0-4"}
      request = HTTP::Request.new("GET", "/", headers)
      response = call_request_on_app(request)

      response.status_code.should eq(200)
      response.headers["Accept-Ranges"].should eq("none")
      response.body.should eq(File.read("#{__DIR__}/asset/hello.ecr"))
    end

    {% unless flag?(:without_zlib) %}
      describe "content coding" do
        it "sends the zlib format for the `deflate` coding" do
          # HTTP's `deflate` is the zlib format of RFC 1950, which opens with a CMF byte of
          # 0x78 for the 32K window; the bare RFC 1951 stream Kemal used to send opens with
          # the first deflate block instead, which is not the coding §8.4.1.2 defines.
          with_compressible_file do |path|
            get "/" do |env|
              send_file env, path
            end

            headers = HTTP::Headers{"Accept-Encoding" => "deflate"}
            response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

            response.headers["Content-Encoding"].should eq("deflate")
            response.body.byte_at(0).should eq(0x78)
            body = IO::Memory.new(response.body)
            Compress::Zlib::Reader.open(body, &.gets_to_end).should eq(File.read(path))
          end
        end

        it "does not use a coding the request refused with q=0" do
          with_compressible_file do |path|
            get "/" do |env|
              send_file env, path
            end

            headers = HTTP::Headers{"Accept-Encoding" => "gzip;q=0"}
            response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

            response.headers["Content-Encoding"]?.should be_nil
            response.body.should eq(File.read(path))
          end
        end

        it "falls back to a coding the request still accepts" do
          with_compressible_file do |path|
            get "/" do |env|
              send_file env, path
            end

            headers = HTTP::Headers{"Accept-Encoding" => "gzip;q=0, deflate"}
            response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

            response.headers["Content-Encoding"].should eq("deflate")
          end
        end

        it "follows the qvalue order of the request" do
          with_compressible_file do |path|
            get "/" do |env|
              send_file env, path
            end

            headers = HTTP::Headers{"Accept-Encoding" => "gzip;q=0.5, deflate;q=1.0"}
            response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

            response.headers["Content-Encoding"].should eq("deflate")
          end
        end

        it "adds `Vary: Accept-Encoding` to a response it compressed" do
          with_compressible_file do |path|
            get "/" do |env|
              send_file env, path
            end

            headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
            response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

            response.headers["Content-Encoding"].should eq("gzip")
            response.headers["Vary"].should eq("Accept-Encoding")
          end
        end

        it "adds `Vary: Accept-Encoding` to a negotiable response it did not compress" do
          # The header describes the URL, not this one response: without it a cache stores the
          # identity body under the URL and hands it to the next client whatever it accepts.
          with_compressible_file do |path|
            get "/" do |env|
              send_file env, path
            end

            response = call_request_on_app(HTTP::Request.new("GET", "/"))

            response.headers["Content-Encoding"]?.should be_nil
            response.headers["Vary"].should eq("Accept-Encoding")
          end
        end

        it "keeps the `Vary` fields the application already set" do
          previous_static_headers = Kemal.config.static_headers

          with_compressible_file do |path|
            Kemal.config.static_headers = ->(env : HTTP::Server::Context, _p : String, _s : File::Info) do
              env.response.headers["Vary"] = "Accept-Language"
            end

            get "/" do |env|
              send_file env, path
            end

            headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
            response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

            response.headers["Vary"].should eq("Accept-Language, Accept-Encoding")
          ensure
            Kemal.config.static_headers = previous_static_headers
          end
        end

        it "does not add `Vary` to a response that is never negotiated" do
          get "/" do |env|
            send_file env, "#{__DIR__}/asset/hello.ecr"
          end

          headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
          response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

          response.headers["Vary"]?.should be_nil
        end

        it "leaves a body that already carries a content coding alone" do
          with_compressible_file do |path|
            get "/" do |env|
              env.response.headers["Content-Encoding"] = "gzip"
              send_file env, path
            end

            headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
            response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

            response.headers["Content-Encoding"].should eq("gzip")
            response.headers["Vary"].should eq("Accept-Encoding")
            # Encoded once by the caller; a second pass would leave a gzip stream inside a
            # gzip stream that no client can read.
            response.body.should eq(File.read(path))
          end
        end

        it "leaves an entity tag the caller set with the encoded body alone" do
          with_compressible_file do |path|
            get "/" do |env|
              env.response.headers["Etag"] = %("app-gzip")
              env.response.headers["Content-Encoding"] = "gzip"
              send_file env, path
            end

            headers = HTTP::Headers{"Accept-Encoding" => "gzip"}
            response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

            # The caller's validator already names the representation the caller encoded.
            response.headers["Etag"].should eq(%("app-gzip"))
          end
        end

        it "declines a multi-range request for a body that carries a content coding" do
          with_compressible_file do |path|
            get "/" do |env|
              env.response.headers["Content-Encoding"] = "gzip"
              send_file env, path
            end

            headers = HTTP::Headers{"Range" => "bytes=0-9,20-29", "Accept-Encoding" => "gzip"}
            response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

            response.status_code.should eq(200)
            response.headers.has_key?("Content-Range").should be_false
            response.body.should eq(File.read(path))
          end
        end

        it "drops the content coding from a 416" do
          with_compressible_file do |path|
            get "/" do |env|
              env.response.headers["Content-Encoding"] = "gzip"
              send_file env, path
            end

            headers = HTTP::Headers{"Range" => "bytes=99999-", "Accept-Encoding" => "gzip"}
            response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

            response.status_code.should eq(416)
            # An empty body is not a valid stream in any coding.
            response.headers["Content-Encoding"]?.should be_nil
            response.headers["Content-Range"].should eq("bytes */#{File.size(path)}")
          end
        end

        it "leaves a range response uncompressed" do
          with_compressible_file do |path|
            get "/" do |env|
              send_file env, path
            end

            headers = HTTP::Headers{"Range" => "bytes=0-9", "Accept-Encoding" => "gzip"}
            response = call_request_on_app(HTTP::Request.new("GET", "/", headers))

            response.status_code.should eq(206)
            response.headers["Content-Encoding"]?.should be_nil
            response.body.should eq(File.read(path)[0, 10])
          end
        end
      end
    {% end %}
  end

  describe "#gzip" do
    it "adds HTTP::CompressHandler to handlers" do
      gzip true
      Kemal.config.setup
      Kemal.config.handlers[5].should be_a(HTTP::CompressHandler)
    end
  end

  describe "#serve_static" do
    it "should disable static file hosting" do
      serve_static false
      Kemal.config.serve_static.should be_false
    end

    it "should enable gzip and dir_listing" do
      serve_static({"gzip" => true, "dir_listing" => true})
      conf = Kemal.config.serve_static
      conf.is_a?(Hash).should be_true
      if conf.is_a?(Hash)
        conf["gzip"].should be_true
        conf["dir_listing"].should be_true
      end
    end
  end
end
