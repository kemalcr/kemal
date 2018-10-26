module Kemal
  # Adds support for `_method` magic parameter to simulate PUT, PATCH, DELETE requests in an html form.
  #
  # This middleware is **not** in the default Kemal handlers. You need to explicitly add this to your handlers:
  #
  # ```ruby
  # add_handler Kemal::OverrideMethodHandler
  # ```
  #
  # **Important:** This middleware consumes `params.body` to read the `_method` magic parameter.
  class OverrideMethodHandler
    include HTTP::Handler
    INSTANCE = new

    ALLOWED_METHODS           = ["PUT", "PATCH", "DELETE"]
    OVERRIDE_METHOD           = "POST"
    OVERRIDE_METHOD_PARAM_KEY = "_method"

    def call(context)
      request = context.request
      if request.method == OVERRIDE_METHOD
        if context.params.body.has_key?(OVERRIDE_METHOD_PARAM_KEY) && override_method_valid?(context.params.body[OVERRIDE_METHOD_PARAM_KEY])
          request.method = context.params.body["_method"].upcase
        end
      end
      call_next(context)
    end

    private def override_method_valid?(override_method : String)
      ALLOWED_METHODS.includes?(override_method.upcase)
    end
  end
end
