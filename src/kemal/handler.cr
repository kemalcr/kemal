module Kemal
  # Kemal::HandlerInterface provides helpful methods for use in middleware creation
  #
  # More specifically, `only`, `only_match?`, `exclude`, `exclude_match?`
  # allows one to define the conditional execution of custom handlers.
  #
  # By default, `only` / `exclude` match a single HTTP method (`GET`) and an
  # exact path. Pass `"*"` as the method to match all methods, and end a path
  # with `"/*"` for prefix matching (same rules as `PathHandler`).
  #
  # For middleware that should run for an entire path subtree on every method,
  # prefer `use "/admin", MyHandler.new` instead of `only`.
  #
  # To use, simply `include` it within your type.
  #
  # It is an implementation of `HTTP::Handler` and can be used anywhere that
  # requests an `HTTP::Handler` type.
  module HandlerInterface
    include HTTP::Handler

    # Public marker for "match every HTTP method" in `only` / `exclude`.
    ALL_METHODS = "*"

    # :nodoc:
    # Radix treats path segments starting with `*` as globs. The public
    # `ALL_METHODS` marker is rewritten to this sentinel in exact-route keys
    # so `only ["/admin"], "*"` stays path-exact.
    ALL_METHODS_KEY = "__ALL__"

    macro included
      @@only_routes_tree = Radix::Tree(String).new
      @@exclude_routes_tree = Radix::Tree(String).new
      # class_name => [{method, prefix}, ...] — grouped to avoid scanning other handlers' rules
      @@only_path_prefixes = {} of String => Array({String, String})
      @@exclude_path_prefixes = {} of String => Array({String, String})
    end

    # :nodoc:
    def self.radix_method(method : String) : String
      method == ALL_METHODS ? ALL_METHODS_KEY : method
    end

    # Restricts the handler to the given paths.
    #
    # Defaults to exact path match for `GET` only. Use `"*"` as *method* to
    # match all HTTP methods. Paths ending with `"/*"` match that prefix
    # (e.g. `"/admin/*"` matches `/admin` and `/admin/users`).
    #
    # ```
    # only ["/admin"]         # GET /admin
    # only ["/admin"], "POST" # POST /admin
    # only ["/admin"], "*"    # any method, exact /admin
    # only ["/admin/*"], "*"  # any method under /admin
    # ```
    macro only(paths, method = "GET")
      ::Kemal::HandlerInterface.__add_handler_routes({{ @type.stringify }}, {{ paths }}, {{ method }}, @@only_routes_tree, @@only_path_prefixes)
    end

    # Excludes the handler from the given paths.
    #
    # Defaults to exact path match for `GET` only. Use `"*"` as *method* to
    # match all HTTP methods. Paths ending with `"/*"` match that prefix.
    #
    # ```
    # exclude ["/public"]
    # exclude ["/assets/*"], "*"
    # ```
    macro exclude(paths, method = "GET")
      ::Kemal::HandlerInterface.__add_handler_routes({{ @type.stringify }}, {{ paths }}, {{ method }}, @@exclude_routes_tree, @@exclude_path_prefixes)
    end

    # :nodoc:
    macro __add_handler_routes(class_name, paths, method, tree, prefixes)
      %class_name = {{ class_name }}
      %method = {{ method }}
      %radix_method = ::Kemal::HandlerInterface.radix_method(%method)
      %class_name_method = "#{%class_name}/#{%radix_method}"
      ({{ paths }}).each do |path|
        if path.ends_with?("/*")
          %prefix = path[0...-2]
          # Keep the public method marker (`"*"` / `"GET"` / …) for prefix rules;
          # only exact-route radix keys need the glob-safe sentinel.
          ({{ prefixes }}[%class_name] ||= [] of {String, String}) << { %method, %prefix }
        else
          {{ tree }}.add %class_name_method + path, '/' + %method + path
        end
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
      matches_scoped_routes?(env, @@only_routes_tree, @@only_path_prefixes)
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
      matches_scoped_routes?(env, @@exclude_routes_tree, @@exclude_path_prefixes)
    end

    private def matches_scoped_routes?(env : HTTP::Server::Context, tree : Radix::Tree(String), prefixes : Hash(String, Array({String, String}))) : Bool
      method = env.request.method
      path = env.request.path
      class_name = self.class.to_s

      return true if tree.find(radix_path(method, path)).found?
      return true if tree.find(radix_path(ALL_METHODS_KEY, path)).found?

      if rules = prefixes[class_name]?
        return true if rules.any? do |(rule_method, prefix)|
                         (rule_method == ALL_METHODS || rule_method == method) && Utils.matches_path_prefix?(prefix, path)
                       end
      end

      false
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
