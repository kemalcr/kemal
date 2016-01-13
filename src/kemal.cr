require "./kemal/*"
require "./kemal/middleware/*"

at_exit do
  Kemal::CLI.new

  config = Kemal.config

  logger = Kemal::Logger.new
  config.add_handler logger
  config.add_handler Kemal::StaticFileHandler.new(config.public_folder)
  config.add_handler Kemal::Handler::INSTANCE

  server = HTTP::Server.new(config.host_binding.not_nil!.to_slice, config.port, config.handlers)
  server.ssl = config.ssl
  logger.write "[#{config.env}] Kemal is ready to lead at #{config.scheme}://#{config.host_binding}:#{config.port}\n"

  Signal::INT.trap {
    logger.write "Kemal is going to take a rest!\n"
    logger.handler.close
    server.close
    exit
  }

  # This route serves the built-in images for not_found and exceptions.
  get "/__kemal__/:image" do |env|
    image = env.params["image"]
    file_path = File.expand_path("libs/kemal/images/#{image}", Dir.current)
    env.add_header "Content-Type", "application/octet-stream"
    File.read(file_path) if File.exists? file_path
  end

  server.listen
end
