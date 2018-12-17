module Kemal::FileHelpers
  extend self

  # Send a file with given path and base the mime-type on the file extension
  # or default `application/octet-stream` mime_type.
  #
  # ```
  # send_file env, "./path/to/file"
  # ```
  #
  # Optionally you can override the mime_type
  #
  # ```
  # send_file env, "./path/to/file", "image/jpeg"
  # ```
  def send_file(env : HTTP::Server::Context, path : String, config : Kemal::Config, mime_type : String? = nil)
    file_path = File.expand_path(path, Dir.current)
    mime_type ||= Kemal::Utils.mime_type(file_path)
    env.response.content_type = mime_type
    env.response.headers["Accept-Ranges"] = "bytes"
    env.response.headers["X-Content-Type-Options"] = "nosniff"
    minsize = 860 # http://webmasters.stackexchange.com/questions/31750/what-is-recommended-minimum-object-size-for-gzip-performance-benefits ??
    request_headers = env.request.headers
    filesize = File.size(file_path)
    filestat = File.info(file_path)

    config.static_headers.try(&.call(env.response, file_path, filestat))
    gzip = config.serve_static?("gzip")

    File.open(file_path) do |file|
      if env.request.method == "GET" && env.request.headers.has_key?("Range")
        next multipart(file, env)
      end
      if request_headers.includes_word?("Accept-Encoding", "gzip") && gzip && filesize > minsize && Kemal::Utils.zip_types(file_path)
        env.response.headers["Content-Encoding"] = "gzip"
        Gzip::Writer.open(env.response) do |deflate|
          IO.copy(file, deflate)
        end
      elsif request_headers.includes_word?("Accept-Encoding", "deflate") && gzip && filesize > minsize && Kemal::Utils.zip_types(file_path)
        env.response.headers["Content-Encoding"] = "deflate"
        Flate::Writer.open(env.response) do |deflate|
          IO.copy(file, deflate)
        end
      else
        env.response.content_length = filesize
        IO.copy(file, env.response)
      end
    end
    return
  end

  def send_file(env, path : String, mime_type : String? = nil)
    send_file(env, path, config, mime_type)
  end

  private def multipart(file, env : HTTP::Server::Context)
    # See http://httpwg.org/specs/rfc7233.html
    fileb = file.size

    range = env.request.headers["Range"]
    match = range.match(/bytes=(\d{1,})-(\d{0,})/)

    startb = 0
    endb = 0

    if match
      if match.size >= 2
        startb = match[1].to_i { 0 }
      end

      if match.size >= 3
        endb = match[2].to_i { 0 }
      end
    end

    if endb == 0
      endb = fileb - 1
    end

    if startb < endb && endb < fileb
      content_length = 1 + endb - startb
      env.response.status_code = 206
      env.response.content_length = content_length
      env.response.headers["Accept-Ranges"] = "bytes"
      env.response.headers["Content-Range"] = "bytes #{startb}-#{endb}/#{fileb}" # MUST

      if startb > 1024
        skipped = 0
        # file.skip only accepts values less or equal to 1024 (buffer size, undocumented)
        until skipped + 1024 > startb
          file.skip(1024)
          skipped += 1024
        end
        if skipped - startb > 0
          file.skip(skipped - startb)
        end
      else
        file.skip(startb)
      end

      IO.copy(file, env.response, content_length)
    else
      env.response.content_length = fileb
      env.response.status_code = 200 # Range not satisfable, see 4.4 Note
      IO.copy(file, env.response)
    end
  end

  def headers(env, additional_headers)
    env.response.headers.merge!(additional_headers)
  end

  # Send a file with given data and default `application/octet-stream` mime_type.
  #
  # ```
  # send_file env, data_slice
  # ```
  #
  # Optionally you can override the mime_type
  #
  # ```
  # send_file env, data_slice, "image/jpeg"
  # ```
  def send_file(env : HTTP::Server::Context, data : Slice(UInt8), mime_type : String? = nil)
    mime_type ||= "application/octet-stream"
    env.response.content_type = mime_type
    env.response.content_length = data.bytesize
    env.response.write data
  end

  # Configures an `HTTP::Server::Response` to compress the response
  # output, either using gzip or deflate, depending on the `Accept-Encoding` request header.
  #
  # Disabled by default.
  def gzip(status : Bool = false)
    add_handler HTTP::CompressHandler.new if status
  end
end
