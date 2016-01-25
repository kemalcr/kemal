# Route is the main building block of Kemal.
# It takes 3 parameters: Method, path and a block to specify
# what action to be done if the route is matched.
class Kemal::Route
  getter handler
  getter method

  def initialize(@method, @path, &@handler : HTTP::Server::Context -> _)
  end

  # Checks if request params contain _method param to override request incoming method
  def self.check_for_method_override!(request)
    request.override_method = request.method
    if request.method == "POST"
      params = Kemal::ParamParser.new(self, request).parse_request
      if params.has_key?("_method") && self.override_method_valid?(params["_method"])
        request.override_method = params["_method"]
      end
    end
  end

  # Checks if method contained in _method param is valid one
  def self.override_method_valid?(override_method)
    return false unless override_method.is_a?(String)
    override_method = override_method.upcase
    return (override_method == "PUT" || override_method == "PATCH" || override_method == "DELETE")
  end
end
