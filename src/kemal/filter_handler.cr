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

    # :nodoc:
    # The filters a `Kemal::Router` attached to one of its routes, keyed by
    # `filter_key` like the global ones. They travel with the `Route` or
    # `Kemal::WebSocket` they guard instead of entering the radix tree below:
    # that tree runs the single best match for the request path, so a router's
    # key was hidden by any more specific key - a top-level filter or another
    # router's - and the guard silently did not run.
    alias ScopedFilters = Hash(String, Array(FilterBlock))

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
      @router_filters = false
    end

    # This middleware is lazily instantiated and added to the handlers as soon as a call to `after_X` or `before_X` is made.
    def initialize
      @tree = Radix::Tree(Array(FilterBlock)).new
      @exact_filters = Hash(String, Array(FilterBlock)).new
      @global_filters = Hash(String, Array(FilterBlock)).new
      @router_filters = false
      Kemal.config.add_filter_handler(self)
    end

    # The call order of the filters is `before_all -> before_x -> X -> after_x -> after_all`.
    def call(context : HTTP::Server::Context)
      # The handshake test is `Kemal::WebSocketHandler`'s own, so the two cannot
      # disagree on whether this request is the one that gets upgraded.
      handshake = Kemal::WebSocketHandler.handshake?(context)

      if !handshake && !context.route_found?
        # A request that matched no route still gets the `before_all` filters: it
        # ends in a 404 or 405 page, and the setup those expect - an
        # authentication check above all - is the same a route gets. This used
        # to depend on whether a custom `error 404`/`405` handler was registered,
        # which `Kemal.run` does outside the `test` environment and nothing does
        # inside it, so a `before_all` guard ran in production and not under spec.
        # The router `before` filters of a route on the path run too, so a router
        # guard or CORS preflight answer covers the methods it does not serve.
        call_block_for_path_type("ALL", context.request.path, :before, context, unrouted_filters(context))
        return call_next(context)
      end

      # A `HEAD` request with no `HEAD` route of its own runs the `GET` handler, so
      # the `GET` filters have to run with it - dispatching on the request method
      # alone let `HEAD /admin/users` bypass a `before_get` authentication filter
      # and slip past `after_get` audit logging. Filters registered for `HEAD`
      # still run, and a route registered explicitly for `HEAD` adds nothing.
      method = context.request.method
      route_method = context.effective_route_method

      # A WebSocket handshake is a `GET` for its `ws` route, so the `GET` filters
      # guard it - top-level and the router's - even where an HTTP route shares
      # the path: the upgrade is what serves the request. Without them a
      # `before_get` guard let the upgrade through. A handshake a filter refuses
      # closes the connection like any other refused upgrade; on a 101 the
      # stdlib replaces the header with `Upgrade`.
      if handshake
        scoped = context.websocket.filters
        context.response.headers["Connection"] = "close"
      else
        scoped = context.route.filters
      end

      call_block_for_path_type("ALL", context.request.path, :before, context, scoped)
      call_block_for_path_type(method, context.request.path, :before, context, scoped)
      call_block_for_path_type(route_method, context.request.path, :before, context, scoped) unless route_method == method
      if Kemal.config.error_handlers.has_key?(context.response.status_code)
        raise Kemal::Exceptions::CustomException.new(context)
      end

      # `after` filters would run once the 101 is on the wire, where writing to
      # the response breaks the connection.
      return call_next(context) if handshake

      call_next(context)
      call_block_for_path_type(route_method, context.request.path, :after, context, scoped) unless route_method == method
      call_block_for_path_type(method, context.request.path, :after, context, scoped)
      call_block_for_path_type("ALL", context.request.path, :after, context, scoped)
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
      register

      if WILDCARD_PATHS.includes?(path)
        key = FilterHandler.filter_key(verb, type)

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

    # :nodoc:
    # Puts this handler in the handler chain, unless it is there already (specs
    # clear the chain between examples).
    def register : Nil
      Kemal.config.add_filter_handler(self) unless Kemal::Config::FILTER_HANDLERS.includes?(self)
    end

    # :nodoc:
    # Called by `Kemal::Router` once it attaches filters to its routes.
    def register_router_filters : Nil
      @router_filters = true
      register
    end

    # The router filters of a route on the request path, for a request no route
    # serves. Only looked up once a router has filters: it probes every
    # registered method, on every miss.
    private def unrouted_filters(context : HTTP::Server::Context) : ScopedFilters?
      return unless @router_filters

      if route = Kemal::RouteHandler::INSTANCE.route_on_path(context.request.path)
        route.filters
      elsif context.ws_route_found?
        context.websocket.filters
      end
    end

    # Executes filters for a given path.
    #
    # Execution order:
    # 1. Global filters (`before_all` / `after_all`) - always run, exactly once
    # 2. Path-specific filters - matched via radix lookup for the request path
    # 3. The matched route's own router filters (*scoped*)
    #
    # Global filters never enter the radix tree, so the path lookup below
    # cannot match them again - duplicate execution is structurally impossible.
    private def call_block_for_path_type(verb : String?, path : String, type, context : HTTP::Server::Context, scoped : ScopedFilters? = nil)
      key = FilterHandler.filter_key(verb, type)
      if global_filters = @global_filters[key]?
        global_filters.each &.call(context)
      end

      # With only global filters registered (`before_all` and friends) the tree
      # is empty, yet every request would still pay a radix key allocation and
      # a lookup per verb/type combination - four to six times per request.
      unless path_filters_empty?
        lookup = lookup_filters_for_path_type(verb, path, type)
        if lookup.found? && lookup.payload.is_a? Array(FilterBlock)
          blocks = lookup.payload
          blocks.each &.call(context)
        end
      end

      if scoped && (blocks = scoped[key]?)
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

    # `tree` is a public getter, so filters can enter the radix tree without
    # going through `_add_route_filter` - ask the tree itself rather than
    # tracking a flag that such additions would bypass.
    private def path_filters_empty? : Bool
      root = @tree.root
      root.children.empty? && root.payload?.nil?
    end

    private def radix_path(verb : String?, path : String, type : Symbol)
      "/#{type}/#{verb}/#{path}"
    end

    # :nodoc:
    def self.filter_key(verb : String?, type : Symbol) : String
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
