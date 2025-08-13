require "kemal"

# Define a route for the root path "/" that will handle file downloads
get "/" do |env|
  # Use Kemal's send_file helper to stream a file to the client
  # Parameters:
  # - env: The HTTP environment containing request/response data
  # - "/path/to/your_file": The path to the file you want to download
  #
  # send_file will:
  # - Set appropriate Content-Type header based on file extension
  # - Stream the file in chunks to handle large files efficiently
  # - Set Content-Disposition header for browser download behavior
  send_file env, "/path/to/your_file"
end

# Start the Kemal web server
Kemal.run
