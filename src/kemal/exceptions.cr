# Exceptions for 404 and custom errors are defined here.
module Kemal::Exceptions
  class InvalidPathStartException < Exception
    def initialize(method, path)
      super "Route declaration #{method} \"#{path}\" needs to start with '/', should be #{method} \"/#{path}\""
    end
  end

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
