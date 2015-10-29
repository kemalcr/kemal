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
    components = request.path.not_nil!.split "/"
    return nil unless request.method == @method
    return nil unless components.size == @components.size
    true
  end
end
