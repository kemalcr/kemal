module Kemal
  class Utils
    def self.path_starts_with_backslash?(path)
      path.starts_with?("/")
    end

    def radix_path(method : String, path)
      "/#{method.downcase}#{path}"
    end
  end
end
