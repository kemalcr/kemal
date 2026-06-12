module Kemal
  # :nodoc:
  class FilterHandler
    include HTTP::Handler
    INSTANCE = new

    # Path spellings that mean "every request path": `before_all` registers
    # on "*" while `before_all "/*"` registers on "/*". Both are normalized
    # into @global_filters at registration time and never enter the radix
    # tree, so a path lookup can never match them a second time (#757).
    private WILDCARD_PATHS = {"*", "/*"}

    @tree : Radix::Tree(Array(FilterBlock))

    # Hash cache for exact path filters to avoid repeated tree lookups
    # Key format: "/#{type}/#{verb}/#{path}" (e.g., "/before/ALL//api")
    @exact_filters : Hash(String, Array(FilterBlock))

    # Global filters (`before_all` / `after_all`), keyed by "#{type}/#{verb}"
    @global_filters : Hash(String, Array(FilterBlock))

    def tree
      @tree
    end

    def tree=(tree : Radix::Tree(Array(FilterBlock)))
      @tree = tree
      @exact_filters = Hash(String, Array(FilterBlock)).new
      @global_filters = Hash(String, Array(FilterBlock)).new
    end

    # This middleware is lazily instantiated and added to the handlers as soon as a call to `after_X` or `before_X` is made.
    def initialize
      @tree = Radix::Tree(Array(FilterBlock)).new
      @exact_filters = Hash(String, Array(FilterBlock)).new
      @global_filters = Hash(String, Array(FilterBlock)).new
      Kemal.config.add_filter_handler(self)
    end

    # The call order of the filters is `before_all -> before_x -> X -> after_x -> after_all`.
    def call(context : HTTP::Server::Context)
      if !context.route_found?
        if Kemal.config.error_handlers.has_key?(404)
          call_block_for_path_type("ALL", context.request.path, :before, context)
        end
        return call_next(context)
      end

      call_block_for_path_type("ALL", context.request.path, :before, context)
      call_block_for_path_type(context.request.method, context.request.path, :before, context)
      if Kemal.config.error_handlers.has_key?(context.response.status_code)
        raise Kemal::Exceptions::CustomException.new(context)
      end

      call_next(context)
      call_block_for_path_type(context.request.method, context.request.path, :after, context)
      call_block_for_path_type("ALL", context.request.path, :after, context)
      context
    end

    # :nodoc:
    # This shouldn't be called directly, it's not private because I need to call it for testing purpose since I can't call the macros in the spec.
    #
    # Registers a filter block for the given verb/path/type combination.
    # Global paths ("*" and "/*") are stored in @global_filters, everything
    # else goes into the radix tree with an @exact_filters hash cache for
    # O(1) lookup when adding multiple filters to the same path.
    def _add_route_filter(verb : String, path, type, &block : HTTP::Server::Context -> _)
      if WILDCARD_PATHS.includes?(path)
        key = global_key(verb, type)

        if filters = @global_filters[key]?
          filters << FilterBlock.new(&block)
        else
          @global_filters[key] = [FilterBlock.new(&block)]
        end

        return
      end

      key = radix_path(verb, path, type)

      if filters = @exact_filters[key]?
        filters << FilterBlock.new(&block)
      else
        filters = [FilterBlock.new(&block)]
        @exact_filters[key] = filters

        @tree.add key, filters
      end
    end

    # This can be called directly but it's simpler to just use the macros,
    # it will check if another filter is not already defined for this
    # verb/path/type and proceed to call `add_route_filter`
    def before(verb : String, path : String = "*", &block : HTTP::Server::Context -> _)
      _add_route_filter verb, path, :before, &block
    end

    # This can be called directly but it's simpler to just use the macros,
    # it will check if another filter is not already defined for this
    # verb/path/type and proceed to call `add_route_filter`
    def after(verb : String, path : String = "*", &block : HTTP::Server::Context -> _)
      _add_route_filter verb, path, :after, &block
    end

    # Executes filters for a given path.
    #
    # Execution order:
    # 1. Global filters (`before_all` / `after_all`) - always run, exactly once
    # 2. Path-specific filters - matched via radix lookup for the request path
    #
    # Global filters never enter the radix tree, so the path lookup below
    # cannot match them again - duplicate execution is structurally impossible.
    private def call_block_for_path_type(verb : String?, path : String, type, context : HTTP::Server::Context)
      if global_filters = @global_filters[global_key(verb, type)]?
        global_filters.each &.call(context)
      end

      lookup = lookup_filters_for_path_type(verb, path, type)
      if lookup.found? && lookup.payload.is_a? Array(FilterBlock)
        blocks = lookup.payload
        blocks.each &.call(context)
      end
    end

    # This checks is filter is already defined for the verb/path/type combination
    private def filter_for_path_type_defined?(verb : String, path : String, type)
      lookup = @tree.find radix_path(verb, path, type)
      lookup.found? && lookup.payload.is_a? FilterBlock
    end

    # This returns a lookup for verb/path/type
    private def lookup_filters_for_path_type(verb : String?, path : String, type)
      @tree.find radix_path(verb, path, type)
    end

    private def radix_path(verb : String?, path : String, type : Symbol)
      "/#{type}/#{verb}/#{path}"
    end

    private def global_key(verb : String?, type : Symbol)
      "#{type}/#{verb}"
    end

    # :nodoc:
    class FilterBlock
      property block : HTTP::Server::Context -> String

      def initialize(&block : HTTP::Server::Context -> _)
        @block = ->(context : HTTP::Server::Context) { block.call(context).to_s }
      end

      def call(context : HTTP::Server::Context)
        @block.call(context)
      end
    end
  end
end
