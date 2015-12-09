# Kemal render uses built-in ECR to render methods.

# # Usage
# get '/' do
#   render 'hello.ecr'
# end

require "ecr/macros"

macro render(filename)
  String.build do |__view__|
    embed_ecr {{filename}}, "__view__"
  end
end
