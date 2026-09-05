{% if !flag?(:without_zlib) %}
  require "compress/deflate"
  require "compress/gzip"
{% end %}
require "mime"

# Adds given `Kemal::Handler` to handlers chain.
# There are 6 handlers by default and all the custom handlers
# goes between the first 5 and the last `Kemal::RouteHandler`.
#
# - `Kemal::InitHandler`
# - `Kemal::LogHandler`
# - `Kemal::HeadRequestHandler`
# - `Kemal::ExceptionHandler`
# - `Kemal::StaticFileHandler`
# - Here goes custom handlers
# - `Kemal::RouteHandler`
@[Deprecated("Use `use` instead")]
def add_handler(handler : HTTP::Handler)
  Kemal.config.add_handler handler
end

@[Deprecated("Use `use` with position parameter instead")]
def add_handler(handler : HTTP::Handler, position : Int32)
  Kemal.config.add_handler handler, position
end

# Sets public folder from which the static assets will be served.
#
# By default this is `/public` not `src/public`.
def public_folder(path : String)
  Kemal.config.public_folder = path
end

# Logs the output via `logger`.
# This is the built-in `Kemal::LogHandler` by default which uses STDOUT.
@[Deprecated("Use standard library Log")]
def log(message : String)
  logger = Kemal.config.logger?
  if logger
    logger.write "#{message}\n"
  else
    Log.info { message }
  end
end

# Enables / Disables logging.
# This is enabled by default.
#
# ```
# logging false
# ```
def logging(status : Bool)
  Kemal.config.logging = status
end

# This is used to replace the built-in `Kemal::LogHandler` with a custom logger.
#
# A custom logger must inherit from `Kemal::BaseLogHandler` and must implement
# `call(context)`, `write(message)` methods.
#
# ```
# class MyCustomLogger < Kemal::BaseLogHandler
#   def call(context)
#     puts "I'm logging some custom stuff here."
#     call_next(context) # => This calls the next handler
#   end
#
#   # This is used from `log` method.
#   def write(message)
#     STDERR.puts message # => Logs the output to STDERR
#   end
# end
# ```
#
# Now that we have a custom logger here's how we use it
#
# ```
# logger MyCustomLogger.new
# ```
@[Deprecated("Use standard library Log")]
def logger(logger : Kemal::BaseLogHandler)
  Kemal.config.logger = logger
end

# Enables / Disables static file serving.
# This is enabled by default.
#
# ```
# serve_static false
# ```
#
# Static server also have some advanced customization options like `dir_listing`,
# `dir_index` and `gzip`.
#
# ```
# serve_static({"gzip" => true, "dir_listing" => false})
# ```
def serve_static(status : Bool)
  Kemal.config.serve_static = status
end

def serve_static(status : Hash(String, V)) forall V
  Kemal.config.serve_static = status
end

# Helper for easily modifying response headers.
# This can be used to modify a response header with the given hash.
#
# ```
# def call(env)
#   headers(env, {"X-Custom-Header" => "This is a custom value"})
# end
# ```
def headers(env : HTTP::Server::Context, additional_headers : Hash(String, String))
  env.response.headers.merge!(additional_headers)
end

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
#
# Also you can set the filename and the disposition
#
# ```
# send_file env, "./path/to/file", filename: "image.jpg", disposition: "attachment"
# ```
def send_file(env : HTTP::Server::Context, path : String, mime_type : String? = nil, *, filename : String? = nil, disposition : String? = nil)
  file_path = File.expand_path(path, Dir.current)
  mime_type ||= MIME.from_filename(file_path, "application/octet-stream")
  env.response.content_type = mime_type
  env.response.headers["Accept-Ranges"] = Kemal.config.max_ranges > 0 ? "bytes" : "none"
  env.response.headers["X-Content-Type-Options"] = "nosniff"
  minsize = 860 # http://webmasters.stackexchange.com/questions/31750/what-is-recommended-minimum-object-size-for-gzip-performance-benefits ??
  request_headers = env.request.headers
  config = Kemal.config.serve_static
  filesize = File.size(file_path)
  filestat = File.info(file_path)
  attachment(env, filename, disposition)

  Kemal.config.static_headers.try(&.call(env, file_path, filestat))

  # RFC 9110 §14.2 defines range handling for GET only, so a `Range` on HEAD is ignored.
  if env.request.method == "GET" && (range_header = env.request.headers["Range"]?)
    ranges = parse_ranges(range_header, filesize)

    # A valid range set none of whose ranges can be satisfied is answered with 416 and the
    # current length, so the client can retry with a range that fits (RFC 9110 §15.5.17).
    if ranges && ranges.empty?
      env.response.status_code = 416
      env.response.headers["Content-Range"] = "bytes */#{filesize}"
      env.response.content_length = 0
      return
    end

    # `nil` means the header was malformed, used a unit other than bytes, or was refused as
    # abusive. Falling through serves the full representation exactly as a plain GET of the
    # same URL would, compression included, instead of a bespoke uncompressed copy that a
    # client could ask for with a two-range header.
    if ranges
      File.open(file_path) { |file| multipart(file, env, ranges) }
      return
    end
  end

  File.open(file_path) do |file|
    {% if flag?(:without_zlib) %}
      env.response.content_length = filesize
      IO.copy(file, env.response)
    {% else %}
      condition = config.is_a?(Hash) && config["gzip"]? == true && filesize > minsize && Kemal::Utils.zip_types(file_path)
      if condition && request_headers.includes_word?("Accept-Encoding", "gzip")
        env.response.headers["Content-Encoding"] = "gzip"
        Compress::Gzip::Writer.open(env.response) do |deflate|
          IO.copy(file, deflate)
        end
      elsif condition && request_headers.includes_word?("Accept-Encoding", "deflate")
        env.response.headers["Content-Encoding"] = "deflate"
        Compress::Deflate::Writer.open(env.response) do |deflate|
          IO.copy(file, deflate)
        end
      else
        env.response.content_length = filesize
        IO.copy(file, env.response)
      end
    {% end %}
  end
  return
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
#
# Also you can set the filename and the disposition
#
# ```
# send_file env, data_slice, filename: "image.jpg", disposition: "attachment"
# ```
def send_file(env : HTTP::Server::Context, data : Slice(UInt8), mime_type : String? = nil, *, filename : String? = nil, disposition : String? = nil)
  mime_type ||= "application/octet-stream"
  env.response.content_type = mime_type
  env.response.content_length = data.bytesize
  attachment(env, filename, disposition)
  env.response.write data
end

private def multipart(file, env : HTTP::Server::Context, ranges : Array({Int64, Int64}))
  # See https://www.rfc-editor.org/rfc/rfc9110#section-14.4 and
  # https://www.rfc-editor.org/rfc/rfc9110#section-15.3.7
  fileb = file.size

  if ranges.size == 1
    # Single range - send as regular partial content
    startb, endb = ranges[0]
    content_length = 1_i64 + endb - startb
    env.response.status_code = 206
    env.response.content_length = content_length
    env.response.headers["Accept-Ranges"] = "bytes"
    env.response.headers["Content-Range"] = "bytes #{startb}-#{endb}/#{fileb}"

    file.seek(startb)
    IO.copy(file, env.response, content_length)
  else
    # Multiple ranges - send as multipart/byteranges. Each body part carries the media type
    # of the selected representation, not the multipart type of the enclosing response.
    content_type = env.response.headers["Content-Type"]
    boundary = "kemal-#{Random::Secure.hex(16)}"
    env.response.content_type = "multipart/byteranges; boundary=#{boundary}"
    env.response.status_code = 206
    env.response.headers["Accept-Ranges"] = "bytes"

    ranges.each do |start_byte, end_byte|
      part_length = 1_i64 + end_byte - start_byte
      env.response.print "--#{boundary}\r\n"
      env.response.print "Content-Type: #{content_type}\r\n"
      env.response.print "Content-Range: bytes #{start_byte}-#{end_byte}/#{fileb}\r\n"
      env.response.print "\r\n"

      file.seek(start_byte)
      IO.copy(file, env.response, part_length)
      env.response.print "\r\n"
    end
    env.response.print "--#{boundary}--\r\n"
  end
end

# Parses a `Range` request header per RFC 9110 §14.1.2 into inclusive `{first, last}` byte
# positions, clamped to the file and with unsatisfiable ranges dropped.
#
# Returns `nil` when the header must be ignored and the full representation served: a unit
# other than `bytes`, a malformed or invalid range-spec, or a range set refused as abusive.
# Returns an empty array when the set is valid but none of its ranges is satisfiable, which
# calls for a `416` (§15.5.17).
private def parse_ranges(range_header : String, file_size : Int64) : Array({Int64, Int64})?
  # Range unit names are case-insensitive (RFC 9110 §16.5.1).
  return unless range_header.size > 6 && range_header[0, 6].compare("bytes=", case_insensitive: true) == 0

  # A range set is only served if it stays within both limits below. Returning `nil` makes
  # `send_file` ignore the header and serve the full representation, which RFC 9110 §14.2
  # allows for range sets that indicate "either a broken client or a deliberate
  # denial-of-service attack".
  max_ranges = Kemal.config.max_ranges
  requested_bytes = 0_i64
  parts = 0
  ranges = [] of {Int64, Int64}

  range_header[6..].split(',') do |spec|
    # Each range costs a seek plus a copy, so an unbounded count lets one request do an
    # unbounded amount of work.
    parts += 1
    return if parts > max_ranges

    # Empty list elements are ignored (RFC 9110 §5.6.1.2).
    next if spec.blank?

    startb, endb = parse_range_spec(spec, file_size) || return

    # A range that selects no bytes is unsatisfiable and dropped; if every range is, the
    # empty result becomes a 416.
    next if endb < startb

    # Overlapping or repeated ranges can ask for many times the file's own size, so a small
    # request would otherwise be amplified into an arbitrarily large response.
    requested_bytes += 1_i64 + endb - startb
    return if requested_bytes > file_size

    ranges << {startb, endb}
  end

  ranges
end

# Parses one range-spec of a `bytes` range set into inclusive `{first, last}` positions
# clamped to *file_size*. Returns `nil` for a malformed or invalid spec, which invalidates
# the whole header (RFC 9110 §14.1.1). An unsatisfiable spec — a first-pos at or beyond the
# end of the file, or a zero suffix-length — comes back with `last < first`.
private def parse_range_spec(spec : String, file_size : Int64) : {Int64, Int64}?
  first, dash, last = spec.strip.partition('-')
  return if dash.empty?

  if first.empty?
    # suffix-range: the last `suffix-length` bytes, or the whole file when it is shorter.
    suffix_length = parse_range_pos(last) || return
    startb = {file_size - suffix_length, 0_i64}.max
    endb = file_size - 1
  else
    # int-range: `first-last`, or `first-` for everything from `first` to the end. A
    # last-pos beyond the end is clamped to it (§14.1.2), whereas a last-pos below the
    # first-pos is invalid.
    startb = parse_range_pos(first) || return
    if last.empty?
      endb = file_size - 1
    else
      endb = parse_range_pos(last) || return
      return if endb < startb
      endb = {endb, file_size - 1}.min
    end
  end

  {startb, endb}
end

# Parses a decimal byte position. Returns `nil` unless *digits* is one or more ASCII digits.
# A value too large for `Int64` lies beyond the end of any file, so it is treated as
# `Int64::MAX` rather than as a parse error: a first-pos that overflows is unsatisfiable,
# and a last-pos or suffix-length that overflows selects up to the end of the file.
private def parse_range_pos(digits : String) : Int64?
  return if digits.empty? || !digits.each_char.all?(&.ascii_number?)
  digits.to_i64? || Int64::MAX
end

# Set the Content-Disposition to "attachment" with the specified filename,
# instructing the user agents to prompt to save.
private def attachment(env : HTTP::Server::Context, filename : String? = nil, disposition : String? = nil)
  disposition = "attachment" if disposition.nil? && filename
  if disposition && filename
    env.response.headers["Content-Disposition"] = "#{disposition}; filename=\"#{File.basename(filename)}\""
  end
end

# Configures an `HTTP::Server::Response` to compress the response
# output, either using gzip or deflate, depending on the `Accept-Encoding` request header.
#
# Disabled by default.
def gzip(status : Bool = false)
  use HTTP::CompressHandler.new if status
end

# Adds headers to `Kemal::StaticFileHandler`. This is especially useful for `CORS`.
#
# ```
# static_headers do |env, filepath, filestat|
#   if filepath =~ /\.html$/
#     env.response.headers.add("Access-Control-Allow-Origin", "*")
#   end
#   env.response.headers.add("Content-Size", filestat.size.to_s)
# end
# ```
def static_headers(&headers : HTTP::Server::Context, String, File::Info ->)
  Kemal.config.static_headers = headers
end
