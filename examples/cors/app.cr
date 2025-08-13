require "kemal"

# Configure headers for static files using Kemal's static_headers helper
static_headers do |response, filepath, filestat|
  # For HTML files, add CORS header to allow requests from example.com
  # This restricts access to HTML files to only that domain
  if filepath =~ /\.html$/
    response.headers.add("Access-Control-Allow-Origin", "example.com")
  end

  # Add Content-Size header for all static files
  # This helps clients know the file size before downloading
  response.headers.add("Content-Size", filestat.size.to_s)
end

# Start the Kemal web server
Kemal.run
