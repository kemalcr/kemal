{% if !flag?(:without_zlib) %}
  require "zlib"
{% end %}

module Kemal
  class StaticFileHandler < HTTP::StaticFileHandler
    def call(context)
      return call_next(context) if context.request.path.not_nil! == "/"

      unless context.request.method == "GET" || context.request.method == "HEAD"
        if @fallthrough
          call_next(context)
        else
          context.response.status_code = 405
          context.response.headers.add("Allow", "GET, HEAD")
        end
        return
      end

      config = Kemal.config.serve_static
      original_path = context.request.path.not_nil!
      is_dir_path = original_path.ends_with? "/"
      request_path = URI.unescape(original_path)

      # File path cannot contains '\0' (NUL) because all filesystem I know
      # don't accept '\0' character as file name.
      if request_path.includes? '\0'
        context.response.status_code = 400
        return
      end

      expanded_path = File.expand_path(request_path, "/")
      if is_dir_path && !expanded_path.ends_with? "/"
        expanded_path = "#{expanded_path}/"
      end
      is_dir_path = expanded_path.ends_with? "/"

      file_path = File.join(@public_dir, expanded_path)
      is_dir = Dir.exists? file_path

      if request_path != expanded_path || is_dir && !is_dir_path
        redirect_to context, "#{expanded_path}#{is_dir && !is_dir_path ? "/" : ""}"
      end

      if Dir.exists?(file_path)
        if config.is_a?(Hash) && config["dir_listing"] == true
          context.response.content_type = "text/html"
          directory_listing(context.response, request_path, file_path)
        else
          return call_next(context)
        end
      elsif File.exists?(file_path)
        return if self.etag(context, file_path)
        minsize = 860 # http://webmasters.stackexchange.com/questions/31750/what-is-recommended-minimum-object-size-for-gzip-performance-benefits ??
        context.response.content_type = mime_type(file_path)
        request_headers = context.request.headers
        filesize = File.size(file_path)
        File.open(file_path) do |file|
          if request_headers.includes_word?("Accept-Encoding", "gzip") && config.is_a?(Hash) && config["gzip"] == true && filesize > minsize && self.zip_types(file_path)
            context.response.headers["Content-Encoding"] = "gzip"
            Zlib::Deflate.gzip(context.response) do |deflate|
              IO.copy(file, deflate)
            end
          elsif request_headers.includes_word?("Accept-Encoding", "deflate") && config.is_a?(Hash) && config["gzip"]? == true && filesize > minsize && self.zip_types(file_path)
            context.response.headers["Content-Encoding"] = "deflate"
            Zlib::Deflate.new(context.response) do |deflate|
              IO.copy(file, deflate)
            end
          else
            context.response.content_length = filesize
            IO.copy(file, context.response)
          end
        end
      else
        call_next(context)
      end
    end

    def etag(context, file_path)
      etag = %{W/"#{File.lstat(file_path).mtime.epoch.to_s}"}
      context.response.headers["ETag"] = etag
      return false if !context.request.headers["If-None-Match"]? || context.request.headers["If-None-Match"] != etag
      context.response.headers.delete "Content-Type"
      context.response.content_length = 0
      context.response.status_code = 304 # not modified
      return true
    end

    def zip_types(path) # https://github.com/h5bp/server-configs-nginx/blob/master/nginx.conf
      [".htm", ".html", ".txt", ".css", ".js", ".svg", ".json", ".xml", ".otf", ".ttf", ".woff", ".woff2"].includes? File.extname(path)
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
      when ".xml"          then "application/xml"
      when ".json"         then "application/json"
      when ".otf", ".ttf"  then "application/font-sfnt"
      when ".woff"         then "application/font-woff"
      when ".woff2"        then "font/woff2"
      else                      "application/octet-stream"
      end
    end
  end
end
