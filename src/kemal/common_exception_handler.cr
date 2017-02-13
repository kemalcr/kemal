module Kemal
  # Kemal::CommonExceptionHandler handles all the exceptions including 404, custom errors and 500.
  class CommonExceptionHandler
    include HTTP::Handler
    INSTANCE = new

    def call(context)
      begin
        call_next(context)
      rescue ex : Kemal::Exceptions::RouteNotFound
        call_exception_with_status_code(context, ex, 404)
      rescue ex : Kemal::Exceptions::CustomException
        call_exception_with_status_code(context, ex, context.response.status_code)
      rescue ex : Exception
        log("Exception: #{ex.inspect_with_backtrace}\n")
        return call_exception_with_status_code(context, ex, 500) if Kemal.config.error_handlers.has_key?(500)
        verbosity = Kemal.config.env == "production" ? false : true
        return render_500(context, ex.inspect_with_backtrace, verbosity)
      end
    end

    private def call_exception_with_status_code(context, exception, status_code)
      if Kemal.config.error_handlers.has_key?(status_code)
        context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
        context.response.print Kemal.config.error_handlers[status_code].call(context, exception)
        context.response.status_code = status_code
        context
      end
    end
  end
end
