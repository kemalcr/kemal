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
