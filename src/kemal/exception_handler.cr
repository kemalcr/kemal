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
      # Use error handler for an ancestor of the current exception if it exists
      Kemal.config.error_handlers.each_key do |key|
        if key.is_a? Exception.class && ex.class <= key
          return call_exception_with_exception(context, ex, 500, override_handler_used: key)
        end
      end

      log("Exception: #{ex.inspect_with_backtrace}")
      # Else use generic 500 handler if defined
      return call_exception_with_status_code(context, ex, 500) if Kemal.config.error_handlers.has_key?(500)
      verbosity = Kemal.config.env == "production" ? false : true
      render_500(context, ex, verbosity)
    end

    # Calls the defined error handler for the given exception if it exists
    #
    # By default it tries to use the handler that is defined for the given exception. However, another
    # handler can be used via the `override_handler_used` parameter.
    private def call_exception_with_exception(context : HTTP::Server::Context, exception : Exception, status_code : Int32 = 500, override_handler_used : (Exception.class)? = nil)
      return if context.response.closed?

      if !override_handler_used
        handler_to_use = exception.class
      else
        handler_to_use = override_handler_used
      end

      if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(handler_to_use)
        context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
        context.response.status_code = status_code
        context.response.print Kemal.config.error_handlers[handler_to_use].call(context, exception)
        context
      end
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
