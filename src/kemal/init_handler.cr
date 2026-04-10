require "http"

module Kemal
  # Initializes the context with default values, such as
  # *Content-Type* or *X-Powered-By* headers.
  class InitHandler
    include HTTP::Handler

    INSTANCE = new

    def call(context : HTTP::Server::Context)
      wrap_request_body_if_needed(context.request)
      context.response.headers.add "X-Powered-By", "Kemal" if Kemal.config.powered_by_header?
      context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
      context.response.headers.add "Date", HTTP.format_time(Time.utc)
      call_next context
    end

    # Limits how many bytes handlers may read from the request body (including
    # `Transfer-Encoding: chunked`). Must run before any handler touches `request.body`.
    # Applies even for `HEAD` if a body IO is present, so a misbehaving client cannot
    # send an unbounded payload on keep-alive connections.
    private def wrap_request_body_if_needed(request : HTTP::Request)
      if (body = request.body) && !body.is_a?(BoundedTotalBodyIO)
        request.body = BoundedTotalBodyIO.new(body, Kemal.config.max_request_body_size)
      end
    end
  end
end
