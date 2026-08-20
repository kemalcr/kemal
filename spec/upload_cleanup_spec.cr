require "./spec_helper"

# Temporary file paths a request spooled to disk, so a spec can assert they are
# gone once the request is over.
UPLOADED_TEMPFILE_PATHS = [] of String

def record_uploads(env)
  UPLOADED_TEMPFILE_PATHS << env.params.files["file"].tempfile.path
end

class UploadBlockingHandler < Kemal::Handler
  only ["/blocked"], "POST"

  def call(env)
    return call_next(env) unless only_match?(env)

    record_uploads(env)
    env.response.status_code = 403
    env.response.print "Forbidden"
    # Deliberately answers without calling the next handler - the shape the
    # `only` docs show for authentication middleware.
  end
end

private def upload_request(path : String)
  boundary = "AaB03x"
  body = <<-MULTIPART
    --#{boundary}\r
    Content-Disposition: form-data; name="file"; filename="upload.txt"\r
    Content-Type: text/plain\r
    \r
    kemal\r
    --#{boundary}\r
    Content-Disposition: form-data; name="token"\r
    \r
    invalid\r
    --#{boundary}--\r
    MULTIPART

  headers = HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=#{boundary}"}
  HTTP::Request.new("POST", path, headers, IO::Memory.new(body))
end

private def uploaded_tempfiles_left_on_disk
  UPLOADED_TEMPFILE_PATHS.select { |path| File.exists?(path) }
end

describe "uploaded temporary file cleanup" do
  before_each do
    UPLOADED_TEMPFILE_PATHS.clear
  end

  after_each do
    UPLOADED_TEMPFILE_PATHS.each { |path| File.delete(path) if File.exists?(path) }
  end

  it "removes the temporary files of a served request" do
    post "/upload" do |env|
      record_uploads(env)
      "Uploaded"
    end

    call_request_on_app(upload_request("/upload")).status_code.should eq(200)

    UPLOADED_TEMPFILE_PATHS.size.should eq(1)
    uploaded_tempfiles_left_on_disk.should be_empty
  end

  # A `before` filter reading `params.body` on a multipart request spools every
  # file part to disk, and halting into a custom error handler skips
  # `Kemal::RouteHandler` entirely - which is where cleanup used to live. An
  # unauthenticated client could fill the disk one rejected upload at a time.
  it "removes the temporary files when a before filter halts into a custom error handler" do
    error 403 do
      "403 Forbidden"
    end

    filter_handler = Kemal::FilterHandler.new
    filter_handler._add_route_filter("POST", "*", :before) do |env|
      if env.params.body["token"]? != "valid_secret"
        record_uploads(env)
        halt env, status_code: 403, response: "Forbidden"
      end
      ""
    end
    Kemal.config.add_filter_handler(filter_handler)

    handler_ran = false
    post "/upload" do
      handler_ran = true
      "Uploaded"
    end

    call_request_on_app(upload_request("/upload")).status_code.should eq(403)

    handler_ran.should be_false
    UPLOADED_TEMPFILE_PATHS.size.should eq(1)
    uploaded_tempfiles_left_on_disk.should be_empty
  end

  it "removes the temporary files when a before filter raises" do
    filter_handler = Kemal::FilterHandler.new
    filter_handler._add_route_filter("POST", "*", :before) do |env|
      record_uploads(env)
      raise "boom" if env.request.method == "POST"
      ""
    end
    Kemal.config.add_filter_handler(filter_handler)

    post "/upload" do
      "Uploaded"
    end

    call_request_on_app(upload_request("/upload")).status_code.should eq(500)

    UPLOADED_TEMPFILE_PATHS.size.should eq(1)
    uploaded_tempfiles_left_on_disk.should be_empty
  end

  it "removes the temporary files when middleware answers without calling the next handler" do
    Kemal.config.add_handler UploadBlockingHandler.new

    handler_ran = false
    post "/blocked" do
      handler_ran = true
      "Uploaded"
    end

    call_request_on_app(upload_request("/blocked")).status_code.should eq(403)

    handler_ran.should be_false
    UPLOADED_TEMPFILE_PATHS.size.should eq(1)
    uploaded_tempfiles_left_on_disk.should be_empty
  end

  it "does not build a param parser for a request that never touches params" do
    get "/no-params" do
      "Hello"
    end

    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/no-params"), response)
    build_main_handler.call(context)
    response.close

    context.params?.should be_nil
  end
end
