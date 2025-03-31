module Kemal
  # Handles all the exceptions, including 404, custom errors and 500.
  class ExceptionHandler
    include HTTP::Handler
    INSTANCE = new

    def call(context : HTTP::Server::Context)
      call_next(context)
    rescue ex : Kemal::Exceptions::RouteNotFound
      call_exception_with_status_code(context, ex, 404)
    rescue ex : Kemal::Exceptions::CustomException
      call_exception_with_status_code(context, ex, context.response.status_code)
    rescue ex : Exception
      # Matches an error handler for the given exception
      #
      # Matches based on order of declaration rather than inheritance relationship
      # for child exceptions
      Kemal.config.exception_handlers.each do |expected_exception, handler|
        if ex.class <= expected_exception
          return call_exception_with_exception(context, ex, handler, 500)
        end
      end

      Log.error(exception: ex) { ex.message }
      # Else use generic 500 handler if defined
      return call_exception_with_status_code(context, ex, 500) if Kemal.config.error_handlers.has_key?(500)
      verbosity = Kemal.config.env == "production" ? false : true
      render_500(context, ex, verbosity)
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
      return if context.response.closed?

      context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
      context.response.status_code = status_code
      context.response.print handler.call(context, exception)
      context
    end

    private def call_exception_with_status_code(context : HTTP::Server::Context, exception : Exception, status_code : Int32)
      return if context.response.closed?
      if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(status_code)
        context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
        context.response.status_code = status_code
        context.response.print Kemal.config.error_handlers[status_code].call(context, exception)
        context
      end
    end
  end
end
