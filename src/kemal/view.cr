# Template for 403 Forbidden
def render_403(context)
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
        <h2>Forbidden</h2>
        <h3>Kemal doesn't allow you to see this page.</h3>
        <img src="/__kemal__/404.png">
      </body>
      </html>
  HTML
  context.response.status_code = 403
  context.response.puts template
end

# Template for 404 Not Found
def render_404(context)
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
  context.response.status_code = 404
  context.response.puts template
end

# Template for 500 Internal Server Error
def render_500(context, ex)
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
  context.response.status_code = 500
  context.response.puts template
end
