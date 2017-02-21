require "json"
require "uri"
require "tempfile"

module Kemal
  # ParamParser parses the request contents including query_params and body
  # and converts them into a params hash which you can within the environment
  # context.
  class ParamParser
    URL_ENCODED_FORM = "application/x-www-form-urlencoded"
    APPLICATION_JSON = "application/json"
    MULTIPART_FORM   = "multipart/form-data"
    # :nodoc:
    alias AllParamTypes = Nil | String | Int64 | Float64 | Bool | Hash(String, JSON::Type) | Array(JSON::Type)
    getter files

    def initialize(@request : HTTP::Request)
      @url = {} of String => String
      @query = HTTP::Params.new({} of String => Array(String))
      @body = HTTP::Params.new({} of String => Array(String))
      @json = {} of String => AllParamTypes
      @files = {} of String => FileUpload
      @url_parsed = false
      @query_parsed = false
      @body_parsed = false
      @json_parsed = false
    end

    private def unescape_url_param(value : String)
      value.size == 0 ? value : URI.unescape(value)
    rescue
      value
    end

    {% for method in %w(url query body json) %}
    def {{method.id}}
      # check memoization
      return @{{method.id}} if @{{method.id}}_parsed

      parse_{{method.id}}
      # memoize
      @{{method.id}}_parsed = true
      @{{method.id}}
    end
    {% end %}

    private def parse_body
      content_type = @request.headers["Content-Type"]?
      return unless content_type
      if content_type.try(&.starts_with?(URL_ENCODED_FORM))
        @body = parse_part(@request.body)
        return
      end
      if content_type.try(&.starts_with?(MULTIPART_FORM))
        parse_file_upload
        return
      end
    end

    private def parse_query
      @query = parse_part(@request.query)
    end

    private def parse_url
      if params = @request.url_params
        params.each do |key, value|
          @url[key.as(String)] = unescape_url_param(value).as(String)
        end
      end
    end

    private def parse_file_upload
      HTTP::FormData.parse(@request) do |upload|
        next unless upload
        filename = upload.filename
        if !filename.nil?
          @files[upload.name] = FileUpload.new(upload: upload)
        else
          @body[upload.name] = upload.body.gets_to_end
        end
      end
    end

    # Parses JSON request body if Content-Type is `application/json`.
    # If request body is a JSON Hash then all the params are parsed and added into `params`.
    # If request body is a JSON Array it's added into `params` as `_json` and can be accessed
    # like params["_json"]
    private def parse_json
      return unless @request.body && @request.headers["Content-Type"]?.try(&.starts_with?(APPLICATION_JSON))

      body = @request.body.not_nil!.gets_to_end
      case json = JSON.parse(body).raw
      when Hash
        json.each do |key, value|
          @json[key.as(String)] = value.as(AllParamTypes)
        end
      when Array
        @json["_json"] = json
      end
    end

    private def parse_part(part : IO?)
      if part
        HTTP::Params.parse(part.gets_to_end)
      else
        HTTP::Params.parse("")
      end
    end

    private def parse_part(part : String?)
      if part
        HTTP::Params.parse(part.to_s)
      else
        HTTP::Params.parse("")
      end
    end
  end
end
