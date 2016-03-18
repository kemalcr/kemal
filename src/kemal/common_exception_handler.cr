class Kemal::CommonExceptionHandler < HTTP::Handler
  INSTANCE = new

  def call(context)
    begin
      call_next context
    rescue ex : Kemal::Exceptions::RouteNotFound
      context.response.content_type = "text/html"
      Kemal.config.logger.write("Exception: #{ex.inspect_with_backtrace.colorize(:red)}\n")
      return render_404(context)
    rescue ex
      context.response.content_type = "text/html"
      Kemal.config.logger.write("Exception: #{ex.inspect_with_backtrace.colorize(:red)}\n")
      verbosity = Kemal.config.env == "production" ? false : true
      return render_500(context, ex.inspect_with_backtrace, verbosity)
    end
  end
end
