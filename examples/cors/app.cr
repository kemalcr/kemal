require "kemal"

# Configure headers for static files using Kemal's static_headers helper
static_headers do |env, filepath, filestat|
  # Let scripts on https://example.com read HTML files cross-origin (a full
  # origin, not a bare domain). CORS is not access control: anyone can still fetch them.
  if filepath =~ /\.html$/
    env.response.headers["Access-Control-Allow-Origin"] = "https://example.com"
  end

  # Add a custom header with the file size for all static files
  env.response.headers["X-File-Size"] = filestat.size.to_s
end

# Start the Kemal web server
Kemal.run
