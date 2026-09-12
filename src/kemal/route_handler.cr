require "radix"

module Kemal
  # Small, private LRU cache used by the router to avoid full cache clears
  # when many distinct paths are accessed. Keeps get/put at O(1).
  # This is intentionally minimal and file-local to avoid API surface.
  class LRUCache(K, V)
    # Doubly-linked list node
    class Node(K, V)
      property key : K
      property value : V
      property prev : Node(K, V)?
      property next : Node(K, V)?

      def initialize(@key : K, @value : V)
        @prev = nil
        @next = nil
      end
    end

    @capacity : Int32
    @map : Hash(K, Node(K, V))
    @head : Node(K, V)? # most-recent
    @tail : Node(K, V)? # least-recent

    def initialize(@capacity : Int32)
      @map = Hash(K, Node(K, V)).new
      @head = nil
      @tail = nil
    end

    def size : Int32
      @map.size
    end

    def get(key : K) : V?
      if node = @map[key]?
        move_to_front(node)
        return node.value
      end
      nil
    end

    def put(key : K, value : V) : Nil
      if node = @map[key]?
        node.value = value
        move_to_front(node)
        return
      end

      # Evict before adding to avoid unnecessary hash resize
      evict_if_at_capacity

      node = Node(K, V).new(key, value)
      @map[key] = node
      insert_front(node)
    end

    def delete(key : K) : Nil
      node = @map.delete(key)
      return unless node

      prev = node.prev
      nxt = node.next

      if prev
        prev.next = nxt
      else
        @head = nxt
      end

      if nxt
        nxt.prev = prev
      else
        @tail = prev
      end
    end

    private def insert_front(node : Node(K, V))
      node.prev = nil
      node.next = @head
      @head.try(&.prev=(node))
      @head = node
      @tail = node if @tail.nil?
    end

    private def move_to_front(node : Node(K, V))
      return if node == @head

      # unlink
      prev = node.prev
      nxt = node.next
      prev.try(&.next=(nxt))
      nxt.try(&.prev=(prev))

      # fix tail if needed
      if node == @tail
        @tail = prev
      end

      insert_front(node)
    end

    private def evict_if_at_capacity
      return if @map.size < @capacity

      if lru = @tail
        # unlink tail
        prev = lru.prev
        if prev
          prev.next = nil
          @tail = prev
        else
          # only one element
          @head = nil
          @tail = nil
        end
        @map.delete(lru.key)
      end
    end
  end

  class RouteHandler
    include HTTP::Handler

    INSTANCE = new

    getter routes

    getter cached_routes

    # Setter is synchronized for thread-safety when specs reset the cache.
    def cached_routes=(cache : LRUCache(String, Radix::Result(Route)))
      @cache_mutex.synchronize { @cached_routes = cache }
    end

    # Rebuilds the verb index `allowed_methods` probes with, so a tree handed
    # over wholesale advertises the routes it already carries instead of none.
    def routes=(routes : Radix::Tree(Route))
      @registered_methods = collect_methods(routes.root)
      @routes = routes
    end

    def initialize
      @routes = Radix::Tree(Route).new
      @registered_methods = Set(String).new
      @cached_routes = LRUCache(String, Radix::Result(Route)).new(Kemal.config.max_route_cache_size)
      @cache_mutex = Mutex.new
    end

    private def collect_methods(node : Radix::Node(Route), methods = Set(String).new) : Set(String)
      if payload = node.payload?
        methods << payload.method
      end
      node.children.each { |child| collect_methods(child, methods) }
      methods
    end

    def call(context : HTTP::Server::Context)
      process_request(context)
    end

    # Adds a given route to routing tree.
    def add_route(method : String, path : String, &handler : HTTP::Server::Context -> _)
      add_to_radix_tree method, path, Route.new(method, path, &handler)
      # A HEAD request served through the GET fallback is cached under the HEAD
      # key. A HEAD route registered for that path afterwards has to drop that
      # entry or the stale fallback keeps winning - and it now also decides which
      # verb scoped filters and only/exclude rules apply. Only the one key is
      # dropped, so the rest of the cache and its capacity survive.
      if method == "HEAD"
        @cache_mutex.synchronize { @cached_routes.delete(radix_path(method, path)) }
      end
    end

    # Looks up the route from the Radix::Tree for the first time and caches to improve performance.
    # Cache access is synchronized so multiple fibers can call this concurrently.
    def lookup_route(verb : String, path : String)
      lookup_path = radix_path(verb, path)

      @cache_mutex.synchronize do
        if cached_route = @cached_routes.get(lookup_path)
          return cached_route
        end
      end

      route = @routes.find(lookup_path)

      if verb == "HEAD" && !route.found?
        # On HEAD requests, implicitly fallback to running the GET handler.
        get_lookup_path = radix_path("GET", path)
        get_route = @routes.find(get_lookup_path)
        # Cache the HEAD->GET fallback result using the original HEAD lookup_path
        if get_route.found?
          @cache_mutex.synchronize { @cached_routes.put(lookup_path, get_route) }
        end
        route = get_route
      elsif route.found?
        @cache_mutex.synchronize { @cached_routes.put(lookup_path, route) }
      end

      route
    end

    # Returns every HTTP method registered for *path*, in `Allow` header order,
    # or an empty array when nothing is routed there.
    #
    # The radix tree is keyed by `/METHOD/path`, so there is no way to ask it
    # which methods a path carries - each routable verb has to be looked up in
    # turn. `HEAD` is reported wherever `GET` is, matching the `HEAD` -> `GET`
    # fallback in `lookup_route`.
    #
    # Deliberately bypasses the route cache: this only runs for a request that
    # already failed to match, and priming the LRU with one entry per verb would
    # let mismatched requests evict the routes actually being served.
    #
    # Only verbs the application actually registered are probed, so an app
    # serving `GET` and `POST` pays two tree lookups here rather than one per
    # routable verb - this is the path scanner traffic takes. The index is
    # maintained by `add_route` and rebuilt from the tree by `routes=`, which
    # are the two supported ways routes get in. A route pushed straight into the
    # tree through the `routes` getter bypasses both; that path degrades to the
    # pre-405 answer of `404` rather than reporting a wrong `Allow`.
    #
    # A `ws` route is reported as `GET`: the opening handshake is a `GET`
    # (RFC 6455 §4.1), so a path carrying one does support the method. It gets
    # no `HEAD` - the upgrade is the only thing served there, and
    # `Kemal::WebSocketHandler` answers nothing else. The probe sits outside the
    # `@registered_methods` shortcut above because that index only tracks HTTP
    # routes, so a WebSocket-only app would otherwise report nothing at all. It
    # is skipped once an HTTP route has already put `GET` in the list.
    #
    # It adds one lookup in a separate, WebSocket-only tree to every miss:
    # measured at ~40ns on top of the ~490ns a two-verb probe already costs
    # (Crystal 1.21, --release, Apple M-series), and unchanged whether or not
    # the app registers any `ws` routes.
    def allowed_methods(path : String) : Array(String)
      methods = [] of String

      unless @registered_methods.empty?
        {% for method in HTTP_METHODS %}
          if @registered_methods.includes?({{ method.upcase }}) && @routes.find(radix_path({{ method.upcase }}, path)).found?
            methods << {{ method.upcase }}
            {% if method == "get" %}
              methods << "HEAD"
            {% end %}
          end
        {% end %}

        # There is no `head` route DSL verb, but `add_route` accepts one, so a
        # `HEAD` route standing on its own still has to be advertised.
        if !methods.includes?("HEAD") && @registered_methods.includes?("HEAD") &&
           @routes.find(radix_path("HEAD", path)).found?
          methods << "HEAD"
        end
      end

      if !methods.includes?("GET") && Kemal::WebSocketHandler::INSTANCE.lookup_ws_route(path).found?
        methods.unshift("GET")
      end

      methods
    end

    # Processes the route if it's a match. Otherwise renders 405 when the path
    # is routed for another method, and 404 when it is not routed at all.
    private def process_request(context)
      # A filter that already answered - `halt` - leaves nothing to route and
      # nothing to advertise, so this comes before the miss handling below and
      # spares it the per-verb probe.
      return if context.response.closed?

      # The route key below is the method concatenated with the path, so a method
      # that is not an RFC 9110 token - one carrying a `/` - decides for itself
      # where the one ends and the other begins: `GET/admin` + `/secret` builds the
      # same key as `GET` + `/admin/secret` and resolves to that route, while the
      # guards in front of it - `use "/prefix"`, `only`/`exclude`,
      # `before_*`/`after_*` - all match on `request.path` and see only `/secret`
      # (#820). Refused where that ambiguity would be spent, so nothing routes on a
      # method and a path that cannot both be believed.
      #
      # The connection does not get to carry another request either: a request line
      # Kemal reads one way and an intermediary in front of it reads another is the
      # parsing disagreement request smuggling is built on (RFC 9112 §11.2), and
      # `close` is the signal for ending it (§9.6). The header survives a custom
      # `error 400`, which `Kemal::ExceptionHandler` dispatches without touching
      # response headers.
      unless Utils.valid_method?(context.request.method)
        context.response.headers["Connection"] = "close"
        raise Kemal::Exceptions::BadRequest.new
      end

      unless context.route_found?
        # RFC 9110 §15.5.6: an existing resource that does not support the
        # request method is a 405, not a 404.
        allowed = allowed_methods(context.request.path)
        # A method that is itself allowed cannot be the reason this missed, so
        # answering "405, Allow: GET" to a `GET` would be nonsense. This happens
        # on a `ws` path reached without an `Upgrade` header: the handshake verb
        # is allowed there, this particular request just is not a handshake.
        # Falls through to the 404 that predates 405 handling.
        unless allowed.empty? || allowed.includes?(context.request.method)
          raise Kemal::Exceptions::MethodNotAllowed.new(context, allowed)
        end
        raise Kemal::Exceptions::RouteNotFound.new(context)
      end

      validate_query_request!(context.request)
      content = context.route.handler.call(context)

      if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(context.response.status_code)
        raise Kemal::Exceptions::CustomException.new(context)
      end

      context.response.print(content)

      context
    end

    # RFC 10008 requires failing a QUERY request whose content lacks a media
    # type. Only the missing-header case is enforced here; rejecting
    # unsupported or unprocessable media types (415/406/422) is up to the
    # application.
    private def validate_query_request!(request : HTTP::Request)
      return unless request.method == "QUERY"
      return if request.headers["Content-Type"]?.presence
      raise Kemal::Exceptions::InvalidQueryRequest.new if request_has_body?(request)
    end

    # Body presence follows RFC 9112 message framing: Transfer-Encoding takes
    # precedence over Content-Length, and an unparsable Content-Length falls
    # back to how the request was actually framed.
    private def request_has_body?(request : HTTP::Request) : Bool
      return true if request.headers["Transfer-Encoding"]?.try(&.downcase.includes?("chunked"))
      if length = request.headers["Content-Length"]?.try(&.to_i64?)
        return length > 0
      end
      !request.body.nil?
    end

    private def radix_path(method, path)
      "/#{method}#{path}"
    end

    private def add_to_radix_tree(method, path, route)
      node = radix_path method, path
      @registered_methods << method
      @routes.add node, route
    end
  end
end
