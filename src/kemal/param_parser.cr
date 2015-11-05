# ParamParser parses the request contents including query_params and body
# and converts them into a params hash which you can within the environment
# context.
class Kemal::ParamParser
  URL_ENCODED_FORM = "application/x-www-form-urlencoded"

  def initialize(@route, @request)
    @route_components = route.components
    @request_components = request.path.not_nil!.split "/"
    @params = {} of String => String
  end

  def parse
    parse_components
    parse_request
  end

  def parse_request
    parse_query
    parse_body
    @params
  end

  def parse_body
    return unless @request.headers["Content-Type"]? == URL_ENCODED_FORM
    parse_part(@request.body)
  end

  def parse_query
    parse_part(@request.query)
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
