require "ecr/macros"

# Uses built-in ECR to render views.
# # Usage
# get '/' do
#   render 'hello.ecr'
# end
macro render(filename)
  String.build do |__view__|
    embed_ecr({{filename}}, "__view__")
  end
end

macro render(filename, layout)
  content = render {{filename}}
  render {{layout}}
end

macro redirect(url)
  env.response.headers.add "Location", {{url}}
  env.response.status_code = 301
end

# Uses Kemal::Middleware::HTTPBasicAuth to easily add HTTP Basic Auth support.
macro basic_auth(username, password)
  auth_handler = Kemal::Middleware::HTTPBasicAuth.new({{username}}, {{password}})
  Kemal.config.add_handler auth_handler
end

macro public_folder(path)
  Kemal.config.public_folder = {{path}}
end
