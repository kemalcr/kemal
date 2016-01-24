class Kemal::StaticFileHandler < HTTP::StaticFileHandler
  def call(context)
    return call_next(context) if context.request.path.not_nil! == "/"
    super
  end
end
