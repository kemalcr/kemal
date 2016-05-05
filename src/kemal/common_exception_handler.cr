module Kemal
  class CommonExceptionHandler < HTTP::Handler
    INSTANCE = new

    def call(context)
      begin
        call_next(context)
      rescue ex : Kemal::Exceptions::RouteNotFound
        return Kemal.config.error_handlers[404].call(context)
      rescue ex1 : Kemal::Exceptions::CustomException
        status_code = ex1.context.response.status_code
        return Kemal.config.error_handlers[status_code].call(context) if Kemal.config.error_handlers.key?(status_code)
      rescue ex2
        Kemal.config.error_handlers[500].call(context) if Kemal.config.error_handlers.key?(500)
        context.response.content_type = "text/html"
        Kemal.config.logger.write("Exception: #{ex2.inspect_with_backtrace}\n")
        verbosity = Kemal.config.env == "production" ? false : true
        return render_500(context, ex2.inspect_with_backtrace, verbosity)
      end
    end
  end
end
