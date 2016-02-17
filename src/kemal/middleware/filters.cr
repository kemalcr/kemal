module Kemal::Middleware
  # Kemal::Filter handle all code that should be evaluated before and after
  # every request
  class Filter < HTTP::Handler
    INSTANCE = new

    # This middleware is lazily instantiated and added to the handlers as soon as a call to `after_X` or `before_X` is made.
    def initialize
      @tree = Radix::Tree.new
      Kemal.config.add_handler(self)
    end

    # The call order of the filters is before_all -> before_x -> X -> after_x -> after_all
    def call(context)
      return call_next(context) unless context.route_defined?
      call_block_for_path_type("ALL", context.request.path, :before, context)
      call_block_for_path_type(context.request.override_method, context.request.path, :before, context)
      call_next(context)
      call_block_for_path_type(context.request.override_method, context.request.path, :after, context)
      call_block_for_path_type("ALL", context.request.path, :after, context)
      context
    end

    # This checks is filter is already defined for the verb/path/type combination
    def filter_for_path_type_defined?(verb, path, type)
      lookup = @tree.find radix_path(verb, path, type)
      lookup.found? && lookup.payload.is_a? Block
    end

    # :nodoc: This shouldn't be called directly, it's not private because I need to call it for testing purpose since I can't call the macros in the spec.
    # It adds the block for the corresponding verb/path/type combination to the tree.
    def _add_route_filter(verb, path, type, &block : HTTP::Server::Context -> _)
      node = radix_path(verb, path, type)
      @tree.add node, Block.new &block
    end

    # This can be called directly but it's simpler to just use the macros, it will check if another filter is not already defined for this verb/path/type and proceed to call `add_route_filter`
    def before(verb = "all", path = "*", &block : HTTP::Server::Context -> _)
      raise Kemal::Middleware::Filter::BeforeFilterAlreadyDefinedException.new(verb, path) if filter_for_path_type_defined?(verb, path, :before)
      _add_route_filter verb, path, :before, &block
    end

    def before(path = "*", &block : HTTP::Server::Context -> _)
      before("all", path, &block)
    end

    # This can be called directly but it's simpler to just use the macros, it will check if another filter is not already defined for this verb/path/type and proceed to call `add_route_filter`
    def after(verb = "all", path = "*", &block : HTTP::Server::Context -> _)
      raise Kemal::Middleware::Filter::AfterFilterAlreadyDefinedException.new(verb, path) if filter_for_path_type_defined?(verb, path, :after)
      _add_route_filter verb, path, :after, &block
    end

    def after(path = "*", &block : HTTP::Server::Context -> _)
      after("all", path, &block)
    end

    # This will fetch the block for the verb/path/type from the tree and call it.
    private def call_block_for_path_type(verb, path, type, context)
      lookup = @tree.find radix_path(verb, path, type)
      if lookup.found? && lookup.payload.is_a? Block
        block = lookup.payload as Block
        block.block.call(context)
      end
    end

    private def radix_path(verb, path, type : Symbol)
      "#{type}/#{verb}/#{path}"
    end

    class BeforeFilterAlreadyDefinedException < Exception
      def initialize(verb, path)
        super "A before-filter is already defined for path: '#{verb}:#{path}'."
      end
    end

    class AfterFilterAlreadyDefinedException < Exception
      def initialize(verb, path)
        super "An after-filter is already defined for path: '#{verb}:#{path}'."
      end
    end
  end

  class Block
    property block

    def initialize(&@block : HTTP::Server::Context -> _)
    end
  end
end

# All the helper methods available are:
#  - before_all, before_get, before_post, before_put, before_patch, before_delete
#  - after_all, after_get, after_post, after_put, after_patch, after_delete

ALL_METHODS = %w(get post put patch delete)
{% for type in ["before", "after"] %}
  {% for method in ALL_METHODS %}
    def {{type.id}}_{{method.id}}(path = "*", &block : HTTP::Server::Context -> _)
     Kemal::Middleware::Filter::INSTANCE.{{type.id}}({{method}}.upcase, path, &block)
    end
  {% end %}
{% end %}
