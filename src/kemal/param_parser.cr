class Kemal::Params
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
    if query = @request.query
      HTTP::Params.parse(query) do |key, value|
        @params[key] ||= value
      end
    end

    if body = @request.body
      HTTP::Params.parse(body.not_nil!) do |key, value|
        @params[key] ||= value
      end
    end
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
