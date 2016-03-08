class Kemal::CommonErrorHandler < HTTP::Handler
  INSTANCE = new

  def call(context)
    begin
      call_next context
    rescue ex : Kemal::Exceptions::RouteNotFound
      Kemal.config.logger.write("Exception: #{ex.inspect_with_backtrace.colorize(:red)}\n")
      return render_404(context)
    rescue ex
      Kemal.config.logger.write("Exception: #{ex.inspect_with_backtrace.colorize(:red)}\n")
      verbosity = Kemal.config.env == "production" ? false : true
      return render_500(context, ex.inspect_with_backtrace, verbosity)
    end
  end
end
