module Kemal
  # Parses the request contents including query_params and body
  # and converts them into a params hash which you can use within
  # the environment context.
  class ParamParser
    URL_ENCODED_FORM = "application/x-www-form-urlencoded"
    APPLICATION_JSON = "application/json"
    MULTIPART_FORM   = "multipart/form-data"
    PARTS = %w(url query body json)
    PERMITTED_URL_TYPES = { 
      "int" => Int32,
      "string" => String,
      "boolean" => Bool
    }

    # :nodoc:
    alias AllParamTypes = Nil | String | Int64 | Float64 | Bool | Hash(String, JSON::Type) | Array(JSON::Type)
    alias AllUrlParamTypes = Int32 | String | Bool
    getter files

    def initialize(@request : HTTP::Request)
      @url = {} of String => AllUrlParamTypes
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

    {% for method in PARTS %}
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
      content_type = @request.content_type
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
          type = (/\[.*\]/).match(key).try &.[0]
          type = type.gsub(/[^a-z0-9]/i, "") unless type.nil?

          if PERMITTED_URL_TYPES.keys.includes?(type)
            parsed_key = key.gsub("[#{type}]", "")
            @url[parsed_key] = UrlTypedParamHandler.cast_as(PERMITTED_URL_TYPES[type], value)
          else
            @url[key] = unescape_url_param(value)
          end
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
          @body.add(upload.name, upload.body.gets_to_end)
        end
      end
    end

    # Parses JSON request body if Content-Type is `application/json`.
    #
    # - If request body is a JSON `Hash` then all the params are parsed and added into `params`.
    # - If request body is a JSON `Array` it's added into `params` as `_json` and can be accessed like `params["_json"]`.
    private def parse_json
      return unless @request.body && @request.headers["Content-Type"]?.try(&.starts_with?(APPLICATION_JSON))

      body = @request.body.not_nil!.gets_to_end
      case json = JSON.parse(body).raw
      when Hash
        json.each do |key, value|
          @json[key] = value.as(AllParamTypes)
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
