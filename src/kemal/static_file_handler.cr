module Kemal
  # Kemal::StaticFileHandler is used to serve static files(.js/.css/.png e.g).
  # This handler is on by default and you can disable it like.
  #
  #   serve_static false
  #
  class StaticFileHandler < HTTP::StaticFileHandler
    def call(context)
      return call_next(context) if context.request.path.not_nil! == "/"
      super
    end
  end
end
