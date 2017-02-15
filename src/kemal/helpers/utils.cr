module Kemal
  module Utils
    def self.path_starts_with_slash?(path)
      path.starts_with?("/")
    end

    def self.zip_types(path) # https://github.com/h5bp/server-configs-nginx/blob/master/nginx.conf
      [".htm", ".html", ".txt", ".css", ".js", ".svg", ".json", ".xml", ".otf", ".ttf", ".woff", ".woff2"].includes? File.extname(path)
    end

    def self.mime_type(path)
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
