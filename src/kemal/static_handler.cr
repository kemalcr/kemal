require "http/server"
require "ecr/macros"

class Kemal::StaticHandler < HTTP::Handler

  def initialize(@publicdir)
  end

  def call(request)
    request_path = request.path.not_nil!

    # Call next handler for processing
    return call_next(request) unless request_path.starts_with? "/public"
    file = request_path.split("/public/")[1] if request_path.starts_with?("/public")
    file_path = File.expand_path("public/#{file}", Dir.working_directory)
    if File.exists?(file_path)
      HTTP::Response.new(200, File.read(file_path), HTTP::Headers{"Content-Type": mime_type(file_path)})
    else
      call_next(request)
    end
  end

  private def mime_type(path)
    case File.extname(path)
    when ".txt"          then "text/plain"
    when ".htm", ".html" then "text/html"
    when ".css"          then "text/css"
    when ".js"           then "application/javascript"
    else                      "application/octet-stream"
    end
  end
end
