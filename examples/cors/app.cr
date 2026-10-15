require "kemal"

# Configure headers for static files using Kemal's static_headers helper
static_headers do |env, filepath, filestat|
  # For HTML files, let scripts on https://example.com read them cross-origin.
  # CORS only relaxes the same-origin policy for browsers; it is not access
  # control, so anyone can still fetch these files directly.
  # The value must be a full origin (scheme + host), not a bare domain.
  if filepath =~ /\.html$/
    env.response.headers["Access-Control-Allow-Origin"] = "https://example.com"
  end

  # Add a custom header with the file size for all static files
  env.response.headers["X-File-Size"] = filestat.size.to_s
end

# Start the Kemal web server
Kemal.run
