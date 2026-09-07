module Kemal
  struct FileUpload
    # The spooled upload, open for reading and positioned at its start.
    getter tempfile : File
    getter filename : String?
    getter headers : HTTP::Headers
    getter creation_time : Time?
    getter modification_time : Time?
    getter read_time : Time?
    # Bytes written to `tempfile` - what is on disk, not what the part's
    # `Content-Disposition` claimed.
    getter size : UInt64?

    def initialize(upload)
      # `File.tempfile` hands back the file open read-write, so the body is written
      # through that handle and it is rewound for the reader. Opening the path a
      # second time to write would cost another descriptor per upload and reopen by
      # name what was just created by descriptor.
      @tempfile = File.tempfile
      begin
        @size = IO.copy(upload.body, @tempfile).to_u64
        @tempfile.flush
        @tempfile.rewind
      rescue ex
        cleanup
        raise ex
      end
      @filename = upload.filename
      @headers = upload.headers
      @creation_time = upload.creation_time
      @modification_time = upload.modification_time
      @read_time = upload.read_time
    end

    def cleanup
      @tempfile.close
      ::File.delete(@tempfile.path) if ::File.exists?(@tempfile.path)
    end
  end
end
