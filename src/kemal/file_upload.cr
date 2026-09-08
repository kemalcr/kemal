module Kemal
  # A file part of a `multipart/form-data` request, spooled to a temporary file
  # that is removed when the request is over.
  #
  # Read it with `open`, or hand `path` to whatever stores it:
  #
  # ```
  # upload = env.params.files["image"]
  # upload.open { |file| IO.copy(file, destination) }
  # File.copy(upload.path, "public/uploads/#{upload.filename}")
  # ```
  class FileUpload
    # Path of the temporary file holding the upload.
    getter path : String
    getter filename : String?
    getter headers : HTTP::Headers
    getter creation_time : Time?
    getter modification_time : Time?
    getter read_time : Time?
    # Bytes written to disk - not what the part's `Content-Disposition` claimed.
    getter size : UInt64?

    # Open only while a caller holds the handle `tempfile` hands out.
    @tempfile : File?

    def initialize(upload)
      # The upload is written through the handle `File.tempfile` opened and that
      # handle is closed at once, so a spooled upload costs a directory entry, not
      # a descriptor held for the rest of the request.
      file = File.tempfile
      @path = file.path
      begin
        @size = IO.copy(upload.body, file).to_u64
      rescue ex
        file.close
        cleanup
        raise ex
      end
      file.close
      @filename = upload.filename
      @headers = upload.headers
      @creation_time = upload.creation_time
      @modification_time = upload.modification_time
      @read_time = upload.read_time
    end

    # Opens the upload for reading, yields the file and closes it.
    def open(& : File -> T) : T forall T
      File.open(@path) { |file| yield file }
    end

    # The upload as an open `File`, positioned at its start, kept open until the
    # request is over. A handle per upload is what the default `ulimit` runs out
    # of a few concurrent requests in; `open` closes when it is done, and `path`
    # needs no handle at all.
    @[Deprecated("Use `open(&)` to read the upload or `path` to move it")]
    def tempfile : File
      @tempfile ||= File.open(@path)
    end

    def cleanup
      @tempfile.try &.close
      ::File.delete(@path) if ::File.exists?(@path)
    end
  end
end
