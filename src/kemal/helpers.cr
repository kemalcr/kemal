require "kilt"

# Uses built-in ECR to render views.
# # Usage
# get '/' do
#   render 'hello.ecr'
# end
macro render(filename)
  __view__ = String::Builder.new
  Kilt.embed({{filename}}, "__view__")
  __view__.to_s
end

macro render(filename, layout)
  content = render {{filename}}
  render {{layout}}
end

def add_handler(handler)
  Kemal.config.add_handler handler
end

# Uses Kemal::Middleware::HTTPBasicAuth to easily add HTTP Basic Auth support.
def basic_auth(username, password)
  auth_handler = Kemal::Middleware::HTTPBasicAuth.new(username, password)
  add_handler auth_handler
end

def public_folder(path)
  Kemal.config.public_folder = path
end

# Logs to output stream.
# development: STDOUT in
# production: kemal.log
def log(message)
  Kemal.config.logger.write "#{message}\n"
end

# Enables / Disables logging
def logging(status)
  Kemal.config.logging = status
end

def logger(logger)
  Kemal.config.logger = logger
  Kemal.config.add_handler logger
end
