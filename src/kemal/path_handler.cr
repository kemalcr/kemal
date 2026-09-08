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
  #
  # A handler instance belongs to one `use`: the wrapped handler continues down
  # the chain from where its wrapper sits, and that is one place.
  class PathHandler
    include HTTP::Handler

    getter path_prefix : String
    getter handler : HTTP::Handler

    def initialize(@path_prefix : String, @handler : HTTP::Handler)
    end

    # Links the wrapped handler to the rest of the chain once, when the chain is
    # built. It used to be re-pointed on every matching request, which under
    # parallel execution let one request re-aim it while another was about to
    # call through it.
    def next=(handler : (HTTP::Handler | HTTP::Handler::HandlerProc)?)
      @handler.next = handler
      super
    end

    def call(context : HTTP::Server::Context)
      if Utils.matches_path_prefix?(@path_prefix, context.request.path)
        @handler.call(context)
      else
        call_next(context)
      end
    end
  end
end
