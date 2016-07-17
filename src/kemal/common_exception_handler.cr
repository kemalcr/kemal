module Kemal
  # Kemal::CommonExceptionHandler handles all the exceptions including 404, custom errors and 500.
  class CommonExceptionHandler < HTTP::Handler
    INSTANCE = new

    def call(context)
      begin
        call_next(context)
      rescue Kemal::Exceptions::RouteNotFound
        call_exception_with_status_code(context, 404)
      rescue Kemal::Exceptions::CustomException
        call_exception_with_status_code(context, context.response.status_code)
      rescue ex : Exception
        Kemal.config.logger.write("Exception: #{ex.inspect_with_backtrace}\n")
        return call_exception_with_status_code(context, 500) if Kemal.config.error_handlers.has_key?(500)
        verbosity = Kemal.config.env == "production" ? false : true
        return render_500(context, ex.inspect_with_backtrace, verbosity)
      end
    end

    def call_exception_with_status_code(context, status_code)
      if Kemal.config.error_handlers.has_key?(status_code)
        context.response.status_code = status_code
        context.response.print Kemal.config.error_handlers[status_code].call(context)
        return context
      end
    end
  end
end
