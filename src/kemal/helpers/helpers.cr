# Adds given Kemal::Handler to handlers chain.
# There are 5 handlers by default and all the custom handlers
# goes between the first 4 and the last `Kemal::RouteHandler`.
#
# - Kemal::InitHandler
# - Kemal::CommonLogHandler
# - Kemal::CommonExceptionHandler
# - Kemal::StaticFileHandler
# - Here goes custom handlers
# - Kemal::RouteHandler
def add_handler(handler)
  Kemal.config.add_handler handler
end

# Sets public folder from which the static assets will be served.
# By default this is `/public` not `src/public`.
def public_folder(path)
  Kemal.config.public_folder = path
end

# Logs the output via `logger`.
# This is the built-in `Kemal::CommonLogHandler` by default which uses STDOUT.
def log(message)
  Kemal.config.logger.write "#{message}\n"
end

# Enables / Disables logging.
# This is enabled by default.
#
#   logging false
def logging(status)
  Kemal.config.logging = status
end

# This is used to replace the built-in `Kemal::CommonLogHandler` with a custom logger.
#
# A custom logger must inherit from `Kemal::BaseLogHandler` and must implement
# `call(env)`, `write(message)` methods.
#
#   class MyCustomLogger < Kemal::BaseLogHandler
#
#     def call(env)
#       puts "I'm logging some custom stuff here."
#       call_next(env) # => This calls the next handler
#     end
#
#     # This is used from `log` method.
#     def write(message)
#       STDERR.puts message # => Logs the output to STDERR
#     end
#   end
#
# Now that we have a custom logger here's how we use it
#
#   logger MyCustomLogger.new
def logger(logger)
  Kemal.config.logger = logger
  Kemal.config.add_handler logger
end

# Enables / Disables static file serving.
# This is enabled by default.
#
# serve_static false
#
# Static server also have some advanced customization options like `dir_listing` and
# `gzip`.
#
# serve_static {"gzip" => true, "dir_listing" => false}
def serve_static(status : (Bool | Hash))
  Kemal.config.serve_static = status
end

# Helper for easily modifying response headers.
# This can be used to modify a response header with the given hash.
#
#   def call(env)
#     headers(env, {"custom-header" => "This is a custom value"})
#   end
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
  mime_type ||= "application/octet-stream"
  env.response.content_type = mime_type
  env.response.content_length = File.size(file_path)
  File.open(file_path) do |file|
    IO.copy(file, env.response)
  end
end

# Send a file with given data and default `application/octet-stream` mime_type.
#
#   send_file env, data_slice
#
# Optionally you can override the mime_type
#
#   send_file env, data_slice, "image/jpeg"
def send_file(env, data : Slice(UInt8), mime_type : String? = nil)
  mime_type ||= "application/octet-stream"
  env.response.content_type = mime_type
  env.response.content_length = data.bytesize
  env.response.write data
end

# Configures an `HTTP::Server::Response` to compress the response
# output, either using gzip or deflate, depending on the `Accept-Encoding` request header.
# It's disabled by default.
def gzip(status : Bool = false)
  add_handler HTTP::CompressHandler.new if status
end
