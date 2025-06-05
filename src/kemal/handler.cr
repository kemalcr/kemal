module Kemal
  # Kemal::HandlerInterface provides helpful methods for use in middleware creation
  #
  # More specifically, `only`, `only_match?`, `exclude`, `exclude_match?`
  # allows one to define the conditional execution of custom handlers.
  #
  # To use, simply `include` it within your type.
  #
  # It is an implementation of `HTTP::Handler` and can be used anywhere that
  # requests an `HTTP::Handler` type.
  module HandlerInterface
    include HTTP::Handler

    macro included
      @@only_routes_tree = Radix::Tree(String).new
      @@exclude_routes_tree = Radix::Tree(String).new
    end

    macro only(paths, method = "GET")
      class_name = {{@type.name}}
      class_name_method = "#{class_name}/#{{{method}}}"
      ({{paths}}).each do |path|
        @@only_routes_tree.add class_name_method + path, '/' + {{method}} + path
      end
    end

    macro exclude(paths, method = "GET")
      class_name = {{@type.name}}
      class_name_method = "#{class_name}/#{{{method}}}"
      ({{paths}}).each do |path|
        @@exclude_routes_tree.add class_name_method + path, '/' + {{method}} + path
      end
    end

    def call(context : HTTP::Server::Context)
      call_next(context)
    end

    # Processes the path based on `only` paths which is a `Array(String)`.
    # If the path is not found on `only` conditions the handler will continue processing.
    # If the path is found in `only` conditions it'll stop processing and will pass the request
    # to next handler.
    #
    # However this is not done automatically. All handlers must inherit from `Kemal::Handler`.
    #
    # ```
    # class OnlyHandler < Kemal::Handler
    #   only ["/"]
    #
    #   def call(env)
    #     return call_next(env) unless only_match?(env)
    #     puts "If the path is / i will be doing some processing here."
    #   end
    # end
    # ```
    def only_match?(env : HTTP::Server::Context)
      @@only_routes_tree.find(radix_path(env.request.method, env.request.path)).found?
    end

    # Processes the path based on `exclude` paths which is a `Array(String)`.
    # If the path is not found on `exclude` conditions the handler will continue processing.
    # If the path is found in `exclude` conditions it'll stop processing and will pass the request
    # to next handler.
    #
    # However this is not done automatically. All handlers must inherit from `Kemal::Handler`.
    #
    # ```
    # class ExcludeHandler < Kemal::Handler
    #   exclude ["/"]
    #
    #   def call(env)
    #     return call_next(env) if exclude_match?(env)
    #     puts "If the path is not / i will be doing some processing here."
    #   end
    # end
    # ```
    def exclude_match?(env : HTTP::Server::Context)
      @@exclude_routes_tree.find(radix_path(env.request.method, env.request.path)).found?
    end

    private def radix_path(method : String, path : String)
      "#{self.class}/#{method}#{path}"
    end
  end

  # `Kemal::Handler` is an implementation of `HTTP::Handler`.
  #
  # It includes `HandlerInterface` to add the methods
  # `only`, `only_match?`, `exclude`, `exclude_match?`.
  # These methods are useful for the conditional execution of custom handlers .
  class Handler
    include HandlerInterface
  end
end
