require "kemal"

# Define a simple route that returns a message
get "/" do
  "Reusing port 3000"
end

# Start Kemal with custom server configuration
Kemal.run do |config|
  # Get the server instance from the config
  # ameba:disable Lint/NotNil
  server = config.server.not_nil!
  # ameba:enable Lint/NotNil

  # Bind the server to port 3000 with reuse_port enabled
  # reuse_port: true allows multiple processes to listen on the same port
  # This is useful for load balancing across multiple worker processes
  server.bind_tcp "0.0.0.0", 3000, reuse_port: true
end
