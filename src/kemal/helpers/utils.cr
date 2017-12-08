module Kemal
  module Utils
    ZIP_TYPES = [".htm", ".html", ".txt", ".css", ".js", ".svg", ".json", ".xml", ".otf", ".ttf", ".woff", ".woff2"]

    def self.path_starts_with_slash?(path : String)
      path.starts_with?("/")
    end

    def self.zip_types(path : String) # https://github.com/h5bp/server-configs-nginx/blob/master/nginx.conf
      ZIP_TYPES.includes? File.extname(path)
    end

    def self.mime_type(path : String)
      case File.extname(path)
      when ".txt"          then "text/plain"
      when ".htm", ".html" then "text/html"
      when ".css"          then "text/css"
      when ".js"           then "application/javascript"
      when ".png"          then "image/png"
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".gif"          then "image/gif"
      when ".svg"          then "image/svg+xml"
      when ".ico"          then "image/x-icon"
      when ".xml"          then "application/xml"
      when ".json"         then "application/json"
      when ".otf", ".ttf"  then "application/font-sfnt"
      when ".woff"         then "application/font-woff"
      when ".woff2"        then "font/woff2"
      when ".mp4"          then "video/mp4"
      when ".webm"         then "video/webm"
      else                      "application/octet-stream"
      end
    end
  end
end
