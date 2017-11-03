class HTTP::Request
  property override_method
  property url_params : Hash(String, String)?
  @param_parser : Kemal::ParamParser?

  def override_method
    @override_method ||= check_for_method_override!
  end

  def content_type
    @headers["Content-Type"]?
  end

  def param_parser
    @param_parser ||= Kemal::ParamParser.new(self)
  end

  # Checks if method contained in _method param is valid one
  def self.override_method_valid?(override_method : String)
    return false unless override_method.is_a?(String)
    override_method = override_method.upcase
    override_method == "PUT" || override_method == "PATCH" || override_method == "DELETE"
  end

  # Checks if request params contain _method param to override request incoming method
  private def check_for_method_override!
    @override_method = @method
    if @method == "POST"
      params = param_parser.body
      if params.has_key?("_method") && HTTP::Request.override_method_valid?(params["_method"])
        @override_method = params["_method"]
      end
    end
    @override_method
  end
end
