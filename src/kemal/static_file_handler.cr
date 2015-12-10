require "http/server"

class Kemal::StaticFileHandler < HTTP::StaticFileHandler
  def call(request)
    request_path = request.path.not_nil!
    return call_next(request) if request_path == "/"
    super
  end
end
