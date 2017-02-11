# :nodoc:
struct FileUpload
  getter tmpfile : Tempfile
  getter tmpfile_path : String
  getter filename : String
  getter meta : HTTP::FormData::FileMetadata
  getter headers : HTTP::Headers

  def initialize(@tmpfile, @tmpfile_path, @meta, @headers)
    @filename = @meta.filename.not_nil!
  end
end