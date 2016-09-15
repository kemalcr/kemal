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

    def mime_type(path)
      case File.extname(path)
      when ".txt"          then "text/plain"
      when ".htm", ".html" then "text/html"
      when ".css"          then "text/css"
      when ".js"           then "application/javascript"
      when ".png"          then "image/png"
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".gif"          then "image/gif"
      when ".svg"          then "image/svg+xml"
      else                      "application/octet-stream"
      end
    end
  end
end
