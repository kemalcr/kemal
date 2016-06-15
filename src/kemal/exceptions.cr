module Kemal::Exceptions
  class RouteNotFound < Exception
    def initialize(context)
      super "Requested path: '#{context.request.override_method.as(String)}:#{context.request.path}' was not found."
    end
  end

  class CustomException < Exception
    def initialize(context)
      super "Rendered error with #{context.response.status_code}"
    end
  end
end
