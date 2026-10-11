module Kemal
  # Handles all the exceptions, including 404, 405, custom errors and 500.
  class ExceptionHandler
    include HTTP::Handler
    INSTANCE = new

    def call(context : HTTP::Server::Context)
      call_next(context)
    rescue ex : Kemal::Exceptions::RouteNotFound
      call_fixed_status(context, ex, 404)
    rescue ex : Kemal::Exceptions::MethodNotAllowed
      call_method_not_allowed(context, ex)
    rescue ex : Kemal::Exceptions::CustomException
      call_exception_with_status_code(context, ex, context.response.status_code)
    rescue ex : Kemal::Exceptions::PayloadTooLarge
      call_fixed_status(context, ex, 413)
    rescue ex : Kemal::Exceptions::InvalidQueryRequest
      call_fixed_status(context, ex, 400)
    rescue ex : Kemal::Exceptions::BadRequest
      # A request the framework could not make sense of - a body it cannot parse
      # (broken JSON, unparseable multipart) or a request line it will not route
      # (a method that is not an RFC 9110 token) - is a client error, so respond
      # 400 instead of 500. Only Kemal's own reading of the request raises this;
      # a parse error in handler code keeps its 500.
      call_fixed_status(context, ex, 400)
    rescue ex : Exception
      # Logged before any handler sees it, so an `error MyException` handler - a
      # catch-all `error Exception` in particular - renders the response without
      # also taking the failure out of the log. The `error 500` path already
      # behaved this way.
      Log.error(exception: ex) { ex.message }
      return if end_connection_if_sent?(context)

      # Matches an error handler for the given exception
      #
      # Matches based on order of declaration rather than inheritance relationship
      # for child exceptions
      Kemal.config.exception_handlers.each do |expected_exception, handler|
        if ex.class <= expected_exception
          return call_exception_with_exception(context, ex, handler, 500)
        end
      end

      # Else use generic 500 handler if defined
      return call_exception_with_status_code(context, ex, 500) if Kemal.config.error_handlers.has_key?(500)
      render_500(context, ex, Kemal.config.show_exceptions?)
    end

    # Calls the given error handler with the current exception
    #
    # The logic for validating that the current exception should be handled
    # by the given error handler should be done by the caller of this method.
    private def call_exception_with_exception(
      context : HTTP::Server::Context,
      exception : Exception,
      handler : Proc(HTTP::Server::Context, Exception, String),
      status_code : Int32 = 500,
    )
      context.response.discard_unsent_body

      context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
      context.response.status_code = status_code
      context.response.print handler.call(context, exception)
      context
    end

    private def call_exception_with_status_code(context : HTTP::Server::Context, exception : Exception, status_code : Int32)
      return if end_connection_if_sent?(context)
      context.response.discard_unsent_body
      if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(status_code)
        context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
        context.response.status_code = status_code
        context.response.print Kemal.config.error_handlers[status_code].call(context, exception)
        context
      end
    end

    # Answers a 405 with the `Allow` header RFC 9110 §15.5.6 makes mandatory.
    # The header is set before dispatching, so a custom `error 405` handler owns
    # the response body but can never drop the header.
    private def call_method_not_allowed(context : HTTP::Server::Context, exception : Kemal::Exceptions::MethodNotAllowed)
      allowed = exception.allowed_methods

      # An empty `Allow` means "this resource allows no methods" (RFC 9110
      # §10.2.1), which contradicts the 405 it would accompany. `process_request`
      # never raises with an empty list, but the exception is public.
      unless allowed.empty? || context.response.closed? || context.response.headers_sent?
        context.response.headers["Allow"] = allowed.join(", ")
      end

      call_fixed_status(context, exception, 405)
    end

    # Dispatches a framework-raised exception with a fixed status code: a custom
    # handler registered for that status if present, otherwise a default
    # plain-text response.
    private def call_fixed_status(context : HTTP::Server::Context, exception : Exception, status_code : Int32)
      if Kemal.config.error_handlers.has_key?(status_code)
        call_exception_with_status_code(context, exception, status_code)
      else
        call_default_exception(context, exception, status_code)
      end
    end

    # Renders a plain-text response for exceptions with a fixed status code
    # when no custom error handler is registered for that code.
    private def call_default_exception(context : HTTP::Server::Context, exception : Exception, status_code : Int32)
      return if end_connection_if_sent?(context)
      context.response.discard_unsent_body

      # The body is Kemal's own, a bare status reason, so the content type is too.
      # `Kemal::InitHandler` has already stamped `text/html` on every response by
      # the time this runs, and a route may have set its own before raising; neither
      # describes the text below.
      context.response.content_type = "text/plain"
      context.response.status_code = status_code
      context.response.print exception.message if exception.message
      context
    end

    # An exception that arrives once the headers are out can have cut the
    # response short: the status line and part of the body are on the wire, and
    # no error page can take their place. When the headers promised a
    # `Content-Length`, a kept-alive connection would carry the next response
    # right after the cut, where a client still reading the promised bytes takes
    # it for the rest of this body - and a proxy pooling the connection hands the
    # mix to someone else. So the connection has to end, and
    # `Connection: close` is how a handler asks `HTTP::Server` for that: it reads
    # the header after the handlers return, before it reads another request
    # (`HTTP::Server::RequestProcessor`), whether or not the header itself can
    # still reach the client. Crystal offers no other way to end it.
    #
    # A chunked response needs none of this: the server ends it with the final
    # chunk either way, so the next response cannot run into it, and the route
    # may well have finished - an `after` filter touching a header of a large
    # response raises here too (#759). A closed response is a finished one - a
    # `halt` closes it with its body complete, and the `CustomException` a
    # status set by `halt` raises arrives after it. Both keep their connection.
    #
    # Returns whether the response had already gone out.
    private def end_connection_if_sent?(context : HTTP::Server::Context) : Bool
      response = context.response
      return true if response.closed?
      return false unless response.headers_sent?

      response.headers["Connection"] = "close" if response.headers.has_key?("Content-Length")
      true
    end
  end
end
