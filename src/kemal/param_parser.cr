module Kemal
  # ParamParser parses the request contents including query_params and body
  # and converts them into a params hash which you can within the environment
  # context.
  class ParamParser
    URL_ENCODED_FORM = "application/x-www-form-urlencoded"
    APPLICATION_JSON = "application/json"
    MULTIPART_FORM   = "multipart/form-data"
    # :nodoc:
    alias AllParamTypes = Nil | String | Array(String) | Int64 | Float64 | Bool | Hash(String, JSON::Type) | Array(JSON::Type)
    getter params, files

    def initialize(@request : HTTP::Request)
      @params = {} of String => AllParamTypes
      @files = {} of String => FileUpload
      @params_parsed = false
    end

    private def unescape_url_param(value : String)
      value.size == 0 ? value : URI.unescape(value)
    rescue
      value
    end

    def parse
      return if @params_parsed
      parse_url
      parse_query
      parse_body
      parse_json
      @params_parsed = true
    end

    private def parse_body
      return unless @request.body
      content_type = @request.headers["Content-Type"]?
      return unless content_type
      if content_type.try(&.starts_with?(URL_ENCODED_FORM))
        parse_part(@request.body)
        return
      end
      if content_type.try(&.starts_with?(MULTIPART_FORM))
        parse_file_upload
        return
      end
    end

    private def parse_query
      return unless @request.query
      parse_part(@request.query)
    end

    private def parse_url
      return unless @request.url_params
      if params = @request.url_params
        params.each do |key, value|
          @params[key] = unescape_url_param(value).as(String)
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
          @params[upload.name] = upload.body.gets_to_end
        end
      end
    end

    # Parses JSON request body if Content-Type is `application/json`.
    # If request body is a JSON Hash then all the params are parsed and added into `params`.
    # If request body is a JSON Array it's added into `params` as `_json` and can be accessed
    # like params["_json"]
    private def parse_json
      return unless @request.body
      return unless @request.headers["Content-Type"]?.try(&.starts_with?(APPLICATION_JSON))

      body = @request.body.not_nil!.gets_to_end
      case json = JSON.parse(body).raw
      when Hash
        json.each do |key, value|
          @params[key] = value.as(AllParamTypes)
        end
      when Array
        @params["_json"] = json
      end
    end

    private def parse_part(part : IO?)
      return unless part
      parse_params(part.gets_to_end)
    end

    private def parse_part(part : String?)
      return unless part
      parse_params(part.to_s)
    end

    private def parse_params(part)
      HTTP::Params.parse(part).each do |key, value|
        if @params.has_key?(key)
          previous_value = @params[key]
          if previous_value.is_a?(Array)
            @params[key].as(Array) << value.as(String)
          else
            @params[key] = [previous_value.as(String), value.as(String)]
          end
        else
          @params[key] ||= value.as(String)
        end
      end
    end
  end
end
