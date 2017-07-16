module Kemal
  # Handles all the exceptions, including 404, custom errors and 500.
  class ExceptionHandler
    include HTTP::Handler

    def call(context : HTTP::Server::Context)
      begin
        call_next(context)
      rescue ex : Kemal::Exceptions::RouteNotFound
        call_exception_with_status_code(context, ex, 404)
      rescue ex : Kemal::Exceptions::CustomException
        call_exception_with_status_code(context, ex, context.response.status_code)
      rescue ex : Exception
        log("Exception: #{ex.inspect_with_backtrace}")
        return call_exception_with_status_code(context, ex, 500) if context.app.error_handlers.has_key?(500)
        verbosity = context.app.config.env == "production" ? false : true
        return render_500(context, ex.inspect_with_backtrace, verbosity)
      end
    end

    private def call_exception_with_status_code(context, exception, status_code)
      if context.app.error_handlers.has_key?(status_code)
        context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
        context.response.print context.app.error_handlers[status_code].call(context, exception)
        context.response.status_code = status_code
        context
      end
    end
  end
end
