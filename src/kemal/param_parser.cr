require "json"

# ParamParser parses the request contents including query_params and body
# and converts them into a params hash which you can within the environment
# context.
alias AllParamTypes = Nil | String | Int64 | Float64 | Bool | Hash(String, JSON::Type) | Array(JSON::Type)

class Kemal::ParamParser
  URL_ENCODED_FORM = "application/x-www-form-urlencoded"
  APPLICATION_JSON = "application/json"

  def initialize(@request)
    @params = {} of String => AllParamTypes
  end

  def parse
    parse_request
  end

  def parse_request
    parse_query
    parse_body
    parse_json
    parse_url_params
    @params
  end

  def parse_body
    return if (@request.headers["Content-Type"]? =~ /#{URL_ENCODED_FORM}/).nil?
    parse_part(@request.body)
  end

  def parse_query
    parse_part(@request.query)
  end

  def parse_url_params
    if params = @request.url_params
      params.each do |key, value|
        @params[key] = value
      end
    end
  end

  # Parses JSON request body if Content-Type is `application/json`.
  # If request body is a JSON Hash then all the params are parsed and added into `params`.
  # If request body is a JSON Array it's added into `params` as `_json` and can be accessed
  # like params["_json"]
  def parse_json
    return unless @request.body && @request.headers["Content-Type"]? == APPLICATION_JSON

    body = @request.body as String
    case json = JSON.parse(body).raw
    when Hash
      json.each do |k, v|
        @params[k as String] = v as AllParamTypes
      end
    when Array
      @params["_json"] = json
    end
  end

  def parse_part(part)
    return unless part
    HTTP::Params.parse(part) do |key, value|
      @params[key] ||= value
    end
  end
end
