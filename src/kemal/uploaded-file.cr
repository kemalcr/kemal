module Kemal
  # Object used to store a reference to a file as part of Kemal::ParamParser
  class UploadedFile
    def initialize(@tmpfile, @filename, @headers)
    end

    getter tmpfile : String, filename : String, headers : HTTP::Headers
  end
end
