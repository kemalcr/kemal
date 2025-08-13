require "kemal"

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
    # Store the new message in history
    messages.push message
    # Broadcast the updated message history to all connected clients
    sockets.each do |a_socket|
      a_socket.send messages.to_json
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
