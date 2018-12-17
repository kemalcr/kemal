def render_404
  Kemal.application.render_404
end

def render_500(context, exception, verbosity)
  Kemal.application.render_500(context, exception, verbosity)
end
