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
    property routes

    getter cached_routes

    # Setter is synchronized for thread-safety when specs reset the cache.
    def cached_routes=(cache : LRUCache(String, Radix::Result(Route)))
      @cache_mutex.synchronize { @cached_routes = cache }
    end

    def initialize
      @routes = Radix::Tree(Route).new
      @cached_routes = LRUCache(String, Radix::Result(Route)).new(Kemal.config.max_route_cache_size)
      @cache_mutex = Mutex.new
    end

    def call(context : HTTP::Server::Context)
      process_request(context)
    end

    # Adds a given route to routing tree.
    def add_route(method : String, path : String, &handler : HTTP::Server::Context -> _)
      add_to_radix_tree method, path, Route.new(method, path, &handler)
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

    # Processes the route if it's a match. Otherwise renders 404.
    private def process_request(context)
      raise Kemal::Exceptions::RouteNotFound.new(context) unless context.route_found?
      return if context.response.closed?
      content = context.route.handler.call(context)

      if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(context.response.status_code)
        raise Kemal::Exceptions::CustomException.new(context)
      end

      context.response.print(content)

      context
    ensure
      context.params.cleanup_temporary_files
    end

    private def radix_path(method, path)
      "/#{method}#{path}"
    end

    private def add_to_radix_tree(method, path, route)
      node = radix_path method, path
      @routes.add node, route
    end
  end
end
