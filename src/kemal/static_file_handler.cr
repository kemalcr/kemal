require "http/server"
require "ecr/macros"

class Kemal::StaticFileHandler < HTTP::Handler
  def call(request)
    request_path = request.path.not_nil!
    return call_next(request) if request_path == "/"
    super
  end
end
