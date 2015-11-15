# Route is the main building block of Kemal.
# It takes 3 parameters method, path and a block to specify
# what action to be done if the route is matched.
class Kemal::Route
  getter handler
  getter components

  def initialize(@method, path, &@handler : Kemal::Context -> _)
    @components = path.split "/"
  end

  def match?(request)
    return nil unless request.method == @method
    components = request.path.not_nil!.split "/"
    return nil unless components.size == @components.size
    @components.zip(components) do |route_component, req_component|
      unless route_component.starts_with? ':'
        return nil unless route_component == req_component
      end
    end
    true
  end
end
