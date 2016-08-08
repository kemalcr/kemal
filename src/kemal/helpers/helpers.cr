# Adds given HTTP::Handler+ to handlers.
def add_handler(handler)
  Kemal.config.add_handler handler
end

# Uses Kemal::Middleware::HTTPBasicAuth to easily add HTTP Basic Auth support.
def basic_auth(username, password)
  auth_handler = Kemal::Middleware::HTTPBasicAuth.new(username, password)
  add_handler auth_handler
end

# Sets public folder from which the static assets will be served.
# By default this is `/public` not `src/public`.
def public_folder(path)
  Kemal.config.public_folder = path
end

# Logs to output stream. STDOUT is the default stream.
def log(message)
  Kemal.config.logger.write "#{message}\n"
end

# Enables / Disables logging
def logging(status)
  Kemal.config.logging = status
end

# Replaces Kemal::CommonLogHandler with a custom logger.
def logger(logger)
  Kemal.config.logger = logger
  Kemal.config.add_handler logger
end

# Enables / Disables static file serving.
def serve_static(status)
  Kemal.config.serve_static = status
end

# Helper for easily modifying response headers.
def headers(env, additional_headers)
  env.response.headers.merge!(additional_headers)
end

# Send a file with given path and default `application/octet-stream` mime_type.
#
#   send_file env, "./path/to/file"
#
# Optionally you can override the mime_type
#
#   send_file env, "./path/to/file", "image/jpeg"
def send_file(env, path : String, mime_type : String? = nil)
  file_path = File.expand_path(path, Dir.current)
  mime_type = "application/octet-stream" unless mime_type
  env.response.headers.add "Content-Type", mime_type
  env.response.content_length = File.size(file_path)
  File.open(file_path) do |file|
    IO.copy(file, env.response)
  end
end

# Send a file with given data and default `application/octet-stream` mime_type.
#
#   send_file env, "./path/to/file"
#
# Optionally you can override the mime_type
#
#   send_file env, "./path/to/file", "image/jpeg"

def send_file(env, data : Slice(UInt8), mime_type : String? = nil)
  mime_type ||= "application/octet-stream"

  env.response.content_type = mime_type
  env.response.content_length = data.bytesize
  env.response.write data
end
