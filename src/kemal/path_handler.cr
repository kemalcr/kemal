module Kemal
  # `PathHandler` wraps a `HTTP::Handler` to only execute for specific path prefixes.
  #
  # ## Example
  #
  # ```
  # use "/api", AuthHandler.new
  # ```
  #
  # The handler will only execute for requests matching the path prefix:
  # - `/api` matches `/api`, `/api/users`, `/api/posts/1`
  # - `/api` does NOT match `/`, `/apiv2`, `/other`
  class PathHandler
    include HTTP::Handler

    getter path_prefix : String
    getter handler : HTTP::Handler

    def initialize(@path_prefix : String, @handler : HTTP::Handler)
    end

    def call(context : HTTP::Server::Context)
      if matches_prefix?(context.request.path)
        # Set next handler for the wrapped handler
        @handler.next = self.next
        @handler.call(context)
      else
        call_next(context)
      end
    end

    # Checks if the request path matches the handler's path prefix.
    # - "/" or "" matches all paths
    # - "/api" matches "/api" and "/api/*"
    # - "/api" does NOT match "/apiv2"
    private def matches_prefix?(path : String) : Bool
      return true if path_prefix.in?("/", "")

      # Exact match
      return true if path == path_prefix

      # Prefix match (must be followed by /)
      path.starts_with?("#{path_prefix}/")
    end
  end
end
