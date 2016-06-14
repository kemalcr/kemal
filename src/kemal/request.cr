# Opening HTTP::Request to add override_method property
class HTTP::Request
  property override_method
  property url_params : Hash(String, String)?

  def override_method
    @override_method ||= check_for_method_override!
  end

  # Checks if request params contain _method param to override request incoming method
  private def check_for_method_override!
    @override_method = @method
    if @method == "POST"
      params = Kemal::ParamParser.new(self).body
      if params.has_key?("_method") && HTTP::Request.override_method_valid?(params["_method"])
        @override_method = params["_method"]
      end
    end
    @override_method
  end

  # Checks if method contained in _method param is valid one
  def self.override_method_valid?(override_method)
    return false unless override_method.is_a?(String)
    override_method = override_method.upcase
    override_method == "PUT" || override_method == "PATCH" || override_method == "DELETE"
  end
end
