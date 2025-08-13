require "kemal"

# Start Kemal with custom server configuration to use Unix Domain Socket
Kemal.run do |config|
  # Get the server instance from the config
  # ameba:disable Lint/NotNil
  server = config.server.not_nil!
  # ameba:enable Lint/NotNil

  # Bind the server to a Unix Domain Socket instead of TCP port
  # Unix Domain Sockets provide faster inter-process communication on the same machine
  # They are commonly used when the client and server are on the same host
  server.bind_unix "path/to/socket.sock"
end
