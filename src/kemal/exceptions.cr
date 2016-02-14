module Kemal::Exceptions
  class RouteNotFound < Exception
    def initialize(context)
      super "Requested path: '#{context.request.override_method as String}:#{context.request.path}' was not found."
    end
  end
end
