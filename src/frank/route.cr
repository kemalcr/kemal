class Frank::Route
  getter handler

  def initialize(path, @handler)
    @components = path.split "/"
  end

  def match(request, components)
    return nil unless components.length == @components.length

    params = nil

    @components.zip(components) do |route_component, req_component|
      if route_component.starts_with? ':'
        params ||= {} of String => String
        params[route_component[1 .. -1]] = req_component
      else
        return nil unless route_component == req_component
      end
    end

    params ||= {} of String => String
    Request.new(params)
  end
end
