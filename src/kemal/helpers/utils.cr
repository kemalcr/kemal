module Kemal
  module Utils
    ZIP_TYPES = {".htm", ".html", ".txt", ".css", ".js", ".svg", ".json", ".xml", ".otf", ".ttf", ".woff", ".woff2"}

    def self.path_starts_with_slash?(path : String)
      path.starts_with? '/'
    end

    def self.zip_types(path : String) # https://github.com/h5bp/server-configs-nginx/blob/master/nginx.conf
      ZIP_TYPES.includes? File.extname(path)
    end

    # Exact prefix, or prefix followed by `/`. `"/"`, and `""` match all paths.
    def self.matches_path_prefix?(prefix : String, path : String) : Bool
      return true if prefix.in?("/", "")

      return true if path == prefix

      path.starts_with?("#{prefix}/")
    end
  end
end
