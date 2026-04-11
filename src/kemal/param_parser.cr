module Kemal
  # Parses the request contents including query_params and body
  # and converts them into a params hash which you can use within
  # the environment context.
  class ParamParser
    private class LimitedBodyIO < IO
      @closed = false
      @bytes_read = 0_i64

      def initialize(@io : IO, limit : Int32)
        @limit = limit.to_i64
      end

      def read(slice : Bytes) : Int32
        check_open

        bytes_read = @io.read(slice)
        increment_bytes_read(bytes_read.to_i64)
        bytes_read
      end

      def read_byte : UInt8?
        check_open

        byte = @io.read_byte
        increment_bytes_read(1_i64) if byte
        byte
      end

      def peek : Bytes?
        check_open
        @io.peek
      end

      def skip(bytes_count) : Nil
        check_open

        @io.skip(bytes_count)
        increment_bytes_read(bytes_count.to_i64)
      end

      def write(slice : Bytes) : NoReturn
        raise IO::Error.new "Can't write to LimitedBodyIO"
      end

      def close : Nil
        @closed = true
      end

      private def increment_bytes_read(bytes_count : Int64)
        return if bytes_count <= 0

        @bytes_read += bytes_count
        raise Exceptions::PayloadTooLarge.new if @bytes_read > @limit
      end
    end

    URL_ENCODED_FORM = "application/x-www-form-urlencoded"
    APPLICATION_JSON = "application/json"
    MULTIPART_FORM   = "multipart/form-data"
    PARTS            = %w[url query body json files]
    # :nodoc:
    alias AllParamTypes = String | Int64 | Float64 | Bool | Hash(String, JSON::Any) | Array(JSON::Any)?
    getter files, all_files

    def initialize(@request : HTTP::Request, @url : Hash(String, String) = {} of String => String)
      @query = HTTP::Params.new({} of String => Array(String))
      @body = HTTP::Params.new({} of String => Array(String))
      @json = {} of String => AllParamTypes
      @files = {} of String => FileUpload
      @all_files = {} of String => Array(FileUpload)
      @url_parsed = false
      @query_parsed = false
      @body_parsed = false
      @json_parsed = false
      @files_parsed = false
      @cached_body = nil
    end

    # Returns the raw request body, read and cached on first access.
    # Allows multiple handlers to access the body without consuming the IO.
    # Only caches for `application/x-www-form-urlencoded` and `application/json`.
    def raw_body : String
      if cached = @cached_body
        return cached
      end

      content_type = @request.headers["Content-Type"]?
      return @cached_body = "" if content_type.nil?

      if content_type.try(&.starts_with?(URL_ENCODED_FORM)) || content_type.try(&.starts_with?(APPLICATION_JSON))
        validate_content_length!
        @cached_body = if body_io = @request.body
                         read_body_with_limit(body_io)
                       else
                         ""
                       end
      else
        @cached_body = ""
      end
    end

    def cleanup_temporary_files
      return if @files.empty? && @all_files.empty?

      @files.each_value &.cleanup
      @all_files.each_value do |file_uploads|
        file_uploads.each &.cleanup
      end
    end

    # Updates url params (e.g. after request method override). Used by Context#invalidate_route_cache.
    def update_url_params(new_url : Hash(String, String))
      @url = new_url
      @url_parsed = false
    end

    private def unescape_url_param(value : String)
      value.empty? ? value : URI.decode(value)
    rescue
      value
    end

    {% for method in PARTS %}
      def {{ method.id }}
        # check memoization
        return @{{ method.id }} if @{{ method.id }}_parsed

        parse_{{ method.id }}
        # memoize
        @{{ method.id }}_parsed = true
        @{{ method.id }}
      end
    {% end %}

    private def parse_body
      content_type = @request.headers["Content-Type"]?

      return unless content_type

      validate_content_length!

      if content_type.try(&.starts_with?(URL_ENCODED_FORM))
        @body = parse_part(raw_body)
        return
      end

      if content_type.try(&.starts_with?(MULTIPART_FORM))
        parse_files
      end
    end

    private def parse_query
      @query = parse_part(@request.query)
    end

    private def parse_url
      @url.each { |key, value| @url[key] = unescape_url_param(value) }
    end

    private def parse_files
      return if @files_parsed

      validate_content_length!

      HTTP::FormData.parse(multipart_body_with_limit, multipart_boundary) do |upload|
        next unless upload

        filename = upload.filename
        name = upload.name

        if !filename.nil?
          if name.ends_with?("[]")
            @all_files[name] ||= [] of FileUpload
            @all_files[name] << FileUpload.new(upload)
          else
            @files[name] = FileUpload.new(upload)
          end
        else
          @body.add(name, read_body_with_limit(upload.body, multipart_form_field_limit))
        end
      end

      @files_parsed = true
    end

    # Parses JSON request body if Content-Type is `application/json`.
    #
    # - If request body is a JSON `Hash` then all the params are parsed and added into `params`.
    # - If request body is a JSON `Array` it's added into `params` as `_json` and can be accessed like `params["_json"]`.
    private def parse_json
      return unless @request.headers["Content-Type"]?.try(&.starts_with?(APPLICATION_JSON))

      body_str = raw_body
      return if body_str.empty?

      case json = JSON.parse(body_str).raw
      when Hash
        json.each do |key, value|
          @json[key] = value.raw
        end
      when Array
        @json["_json"] = json
      else
        # Ignore non Array or Hash json values
      end
    end

    private def parse_part(part : IO?)
      return HTTP::Params.new({} of String => Array(String)) unless part
      body_str = read_body_with_limit(part)
      HTTP::Params.parse(body_str)
    end

    private def parse_part(part : String?)
      HTTP::Params.parse part.to_s
    end

    private def validate_content_length!
      return unless length_str = @request.headers["Content-Length"]?
      return unless length = length_str.to_i?
      return if length <= Kemal.config.max_request_body_size

      raise Exceptions::PayloadTooLarge.new
    end

    private def read_body_with_limit(io : IO, limit : Int32 = Kemal.config.max_request_body_size) : String
      String.build do |str|
        bytes_read = IO.copy(io, str, limit + 1)
        if bytes_read > limit
          raise Exceptions::PayloadTooLarge.new
        end
      end
    end

    private def multipart_form_field_limit : Int32
      Kemal.config.max_multipart_form_field_size
    end

    private def multipart_body_with_limit : IO
      body = @request.body
      raise HTTP::FormData::Error.new("Cannot extract form-data from HTTP request: body is empty") unless body

      LimitedBodyIO.new(body, Kemal.config.max_request_body_size)
    end

    private def multipart_boundary : String
      content_type = @request.headers["Content-Type"]?
      boundary = content_type.try { |header| MIME::Multipart.parse_boundary(header) }
      raise HTTP::FormData::Error.new("Cannot extract form-data from HTTP request: could not find boundary in Content-Type") unless boundary

      boundary
    end
  end
end
