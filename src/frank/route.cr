class Frank::Route
  getter handler

  def initialize(@method, path, &@handler : Frank::Context -> _)
    @components = path.split "/"
  end

  def match(method, components)
    return nil unless method == @method
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
    params
  end
end
