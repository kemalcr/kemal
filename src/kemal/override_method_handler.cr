module Kemal
  class OverrideMethodHandler
    include HTTP::Handler
    INSTANCE = new

    ALLOWED_METHODS           = ["PUT", "PATCH", "DELETE"]
    OVERRIDE_METHOD           = "POST"
    OVERRIDE_METHOD_PARAM_KEY = "_method"

    def call(context)
      request = context.request
      if request.method == OVERRIDE_METHOD
        if context.params.body.has_key?(OVERRIDE_METHOD_PARAM_KEY) && override_method_valid?(context.params.body["_method"])
          request.method = context.params.body["_method"].upcase
        end
      end
      call_next(context)
    end

    def override_method_valid?(override_method : String)
      ALLOWED_METHODS.includes?(override_method.upcase)
    end
  end
end
