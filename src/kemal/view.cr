# Kemal render uses built-in ECR to render methods.

# # Usage
# get '/' do
#   render 'hello.ecr'
# end

require "ecr/macros"

macro render(filename)
  String.build do |__view__|
    embed_ecr({{filename}}, "__view__")
  end
end

macro render(filename, layout)
  content = render {{filename}}
  render {{layout}}
end

def render_404
  template = <<-HTML
      <!DOCTYPE html>
      <html>
      <head>
        <style type="text/css">
        body { text-align:center;font-family:helvetica,arial;font-size:22px;
          color:#888;margin:20px}
        #c {margin:0 auto;width:500px;text-align:left}
        </style>
      </head>
      <body>
        <h2>Kemal doesn't know this way.</h2>
        <img src="/__kemal__/404.png">
      </body>
      </html>
  HTML
  HTTP::Response.new(404, template)
end

def render_500(ex)
  template = <<-HTML
      <!DOCTYPE html>
      <html>
      <head>
        <style type="text/css">
        body { text-align:center;font-family:helvetica,arial;font-size:22px;
          color:#888;margin:20px}
        #c {margin:0 auto;width:500px;text-align:left}
        </style>
      </head>
      <body>
        <h2>Kemal has encountered an error. (500)</h2>
        <p>#{ex}</p>
      </body>
      </html>
  HTML
  HTTP::Response.error("text/html", template)
end
