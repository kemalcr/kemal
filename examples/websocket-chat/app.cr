require "kemal"

# Keep only the latest messages so history memory stays bounded
MAX_MESSAGES = 100
# Longest message kept or broadcast. The stdlib has already read the whole
# message by the time on_message runs, so this does not cap memory per read.
MAX_MESSAGE_BYTES = 1024

# Array to store chat message history
messages = [] of String
# Array to keep track of connected WebSocket clients
sockets = [] of HTTP::WebSocket

# Create WebSocket endpoint at root path "/"
ws "/" do |socket|
  # Send the history once on connect; after that, every frame is one new message
  messages.each { |message| socket.send message }
  # Add newly connected client socket to our sockets array
  sockets.push socket

  # Handle incoming messages from clients
  socket.on_message do |message|
    if message.bytesize > MAX_MESSAGE_BYTES
      socket.close(HTTP::WebSocket::CloseCode::MessageTooBig, "Message too big")
      next
    end

    # Store the new message in history
    messages.push message
    messages.shift if messages.size > MAX_MESSAGES
    # Broadcast only the new message, not the whole history.
    # Iterate a copy: `send` can yield, and on_close may change `sockets` meanwhile.
    sockets.dup.each do |peer|
      peer.send message
    rescue
      # Drop a peer that went away (IO or TLS error) so it is not retried
      sockets.delete(peer)
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
