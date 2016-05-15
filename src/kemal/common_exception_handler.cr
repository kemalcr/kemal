module Kemal
  class CommonExceptionHandler < HTTP::Handler
    INSTANCE = new

    def call(context)
      begin
        call_next(context)
      rescue Kemal::Exceptions::RouteNotFound
        context.response.content_type = "text/html"
        context.response.status_code = 404
        context.response.print Kemal.config.error_handlers[404].call(context)
        return context
      rescue Kemal::Exceptions::CustomException
        status_code = context.response.status_code
        if Kemal.config.error_handlers.has_key?(status_code)
          context.response.print Kemal.config.error_handlers[status_code].call(context)
          return context
        end
      rescue ex : Exception
        context.response.content_type = "text/html"
        Kemal.config.logger.write("Exception: #{ex.inspect_with_backtrace}\n")
        verbosity = Kemal.config.env == "production" ? false : true
        return render_500(context, ex.inspect_with_backtrace, verbosity)
      end
    end
  end
end
