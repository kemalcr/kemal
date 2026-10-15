require "kemal"

# Keep only the latest messages so clients cannot grow memory without bound
MAX_MESSAGES      =  100
MAX_MESSAGE_BYTES = 1024
# Array to store chat message history
messages = [] of String
# Array to keep track of connected WebSocket clients
sockets = [] of HTTP::WebSocket

# Create WebSocket endpoint at root path "/"
ws "/" do |socket|
  # Add newly connected client socket to our sockets array
  sockets.push socket

  # Handle incoming messages from clients
  socket.on_message do |message|
    next if message.bytesize > MAX_MESSAGE_BYTES
    # Store the new message in history
    messages.push message
    messages.shift if messages.size > MAX_MESSAGES
    # Broadcast the updated message history to all connected clients
    payload = messages.to_json
    sockets.each do |a_socket|
      a_socket.send payload
    rescue IO::Error
      # A peer that dropped must not stop delivery to the others
    end
  end

  # Handle client disconnection
  socket.on_close do |_|
    # Remove disconnected client's socket from our array
    sockets.delete(socket)
    # Log disconnection event
    puts "Closing Socket: #{socket}"
  end
end

# Start the Kemal server
Kemal.run
