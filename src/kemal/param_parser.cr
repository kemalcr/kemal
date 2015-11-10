require "json"

# ParamParser parses the request contents including query_params and body
# and converts them into a params hash which you can within the environment
# context.

alias AllParamTypes = Nil | String | Int64 | Float64 | Bool | Hash(String, JSON::Type) | Array(JSON::Type)

class Kemal::ParamParser
  URL_ENCODED_FORM = "application/x-www-form-urlencoded"
  APPLICATION_JSON = "application/json"

  def initialize(@route, @request)
    @route_components = route.components
    @request_components = request.path.not_nil!.split "/"
    @params = {} of String => AllParamTypes
  end

  def parse
    parse_components
    parse_request
  end

  def parse_request
    parse_query
    parse_body
    parse_json
    @params
  end

  def parse_body
    return unless @request.headers["Content-Type"]? == URL_ENCODED_FORM
    parse_part(@request.body)
  end

  def parse_query
    parse_part(@request.query)
  end

  def parse_json
    return unless @request.body && @request.headers["Content-Type"]? == APPLICATION_JSON

    body = @request.body as String

    case json = JSON.parse(body)
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

  def parse_components
    @route_components.zip(@request_components) do |route_component, req_component|
      if route_component.starts_with? ':'
        @params[route_component[1..-1]] = req_component
      else
        return nil unless route_component == req_component
      end
    end
  end
end
