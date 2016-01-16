class Kemal::StaticFileHandler < HTTP::StaticFileHandler
  def call(request)
    return call_next(request) if request.path.not_nil! == "/"
    super
  end
end
