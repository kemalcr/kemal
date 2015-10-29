# ParamParser parses the request contents including query_params and body
# and converts them into a params hash which you can within the environment
# context.
class Kemal::ParamParser
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
    {% for part in %w(query body) %}
      if {{part.id}} = @request.{{part.id}}
        HTTP::Params.parse({{part.id}}) do |key, value|
          @params[key] ||= value
        end
      end
    {% end %}
    @params
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
