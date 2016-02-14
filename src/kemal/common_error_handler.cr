class Kemal::CommonErrorHandler < HTTP::Handler
  INSTANCE = new

  def call(context)
    begin
      call_next context
    rescue ex : Kemal::Exceptions::RouteNotFound
      Kemal.config.logger.write("Exception: #{ex.to_s}\n")
      return render_404(context)
    rescue ex
      Kemal.config.logger.write("Exception: #{ex.to_s}\n")
      return render_500(context, ex.to_s)
    end
  end
end
