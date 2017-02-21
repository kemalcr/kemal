# :nodoc:
module Kemal
  struct FileUpload
    getter tmpfile : Tempfile
    getter filename : String?
    getter headers : HTTP::Headers
    getter creation_time : Time?
    getter modification_time : Time?
    getter read_time : Time?
    getter size : UInt64?

    def initialize(upload)
      @tmpfile = Tempfile.new(filename)
      ::File.open(@tmpfile.path, "w") do |file|
        IO.copy(upload.body, file)
      end
      @filename = upload.filename
      @headers = upload.headers
      @creation_time = upload.creation_time
      @modification_time = upload.modification_time
      @read_time = upload.read_time
      @size = upload.size
    end
  end
end
