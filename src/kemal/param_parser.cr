require "json"

# ParamParser parses the request contents including query_params and body
# and converts them into a params hash which you can within the environment
# context.
alias AllParamTypes = Nil | String | Int64 | Float64 | Bool | Hash(String, JSON::Type) | Array(JSON::Type)

class Kemal::ParamContainer
  getter url
  getter query
  getter body
  getter json

  def initialize(@url, @query, @body, @json)
  end

  def all
    @url.merge(@query).merge(@body).merge(@json)
  end
end

class Kemal::ParamParser
  URL_ENCODED_FORM = "application/x-www-form-urlencoded"
  APPLICATION_JSON = "application/json"

  def initialize(@request)
    @url = {} of String => String
    @query = {} of String => String
    @body = {} of String => String
    @json = {} of String => AllParamTypes
  end

  def params
    parse_request
    Kemal::ParamContainer.new(@url, @query, @body, @json)
  end

  def parse_request
    parse_query
    parse_body
    parse_json
    parse_url_params
  end

  def parse_body
    return if (@request.headers["Content-Type"]? =~ /#{URL_ENCODED_FORM}/).nil?
    @body = parse_part(@request.body)
  end

  def parse_query
    @query = parse_part(@request.query)
  end

  def parse_url_params
    if params = @request.url_params
      params.each do |key, value|
        @url[key as String] = value as String
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
      json.each do |key, value|
        @json[key as String] = value as AllParamTypes
      end
    when Array
      @json["_json"] = json
    end
  end

  def parse_part(part)
    part_params = {} of String => String
    if part
      HTTP::Params.parse(part) do |key, value|
        part_params[key as String] ||= value as String
      end
    end
    part_params
  end
end
