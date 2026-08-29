require "http"

module Kemal
  # Initializes the context with default values, such as
  # *Content-Type* or *X-Powered-By* headers.
  class InitHandler
    include HTTP::Handler

    INSTANCE = new

    # An HTTP `Date` value only changes once a second, while formatting one
    # costs ~215ns and 240B of garbage per request. Held as a single immutable
    # object behind an `Atomic` because the server may run in a parallel
    # execution context: the atomic swap publishes the fully constructed
    # object to other threads instead of tearing a timestamp/string pair
    # updated separately.
    private class CachedDate
      getter unix : Int64
      getter value : String

      def initialize(@unix : Int64, @value : String)
      end
    end

    @cached_date = Atomic(CachedDate).new(CachedDate.new(Int64::MIN, ""))

    def call(context : HTTP::Server::Context)
      context.response.headers.add "X-Powered-By", "Kemal" if Kemal.config.powered_by_header?
      context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
      context.response.headers.add "Date", date_header
      call_next context
    ensure
      # Uploads are spooled to disk by `Kemal::ParamParser` the moment anything
      # touches `params` - including `params.body` on a multipart request, which
      # writes every file part out just to read one form field. That can happen
      # in a `before` filter or in custom middleware, so cleanup cannot belong to
      # `Kemal::RouteHandler`: a `halt` that matches a custom `error` handler, an
      # exception raised in a filter, and middleware that answers without calling
      # the next handler all skip the route handler entirely, leaving the
      # temporary files behind for good. This handler heads Kemal's chain, so it
      # unwinds whatever the rest of it did (#776).
      #
      # A handler registered at position 0 - `use handler, 0` - sits ahead of
      # this one and can answer without ever reaching it. That position already
      # means "before Kemal touches the response", response defaults included, so
      # such a handler owns the cleanup for anything it parses itself.
      begin
        context.params?.try &.cleanup_temporary_files
      rescue ex
        # `Kemal::ExceptionHandler` is further down the chain, so an exception
        # raised here would escape Kemal entirely and drop the client's
        # connection mid-response. A temp file that resists removal is worth a
        # log line, not a broken response.
        Log.error(exception: ex) { "Failed to clean up uploaded temporary files" }
      end
    end

    private def date_header : String
      now = Time.utc
      epoch = now.to_unix
      cached = @cached_date.get
      return cached.value if cached.unix == epoch

      formatted = HTTP.format_time(now)
      @cached_date.set(CachedDate.new(epoch, formatted))
      formatted
    end
  end
end
