module Kemal
  class Utils
    def self.path_starts_with_backslash?(path)
      path.starts_with?("/")
    end
  end
end
