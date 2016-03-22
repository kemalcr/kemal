require "./kemal/*"
require "./kemal/middleware/*"

module Kemal
  def self.run
    Kemal::CLI.new
    config = Kemal.config
    config.setup
    config.add_handler Kemal::RouteHandler::INSTANCE

    server = HTTP::Server.new(config.host_binding.not_nil!, config.port, config.handlers)
    server.ssl = config.ssl

    Signal::INT.trap {
      config.logger.write "Kemal is going to take a rest!\n"
      server.close
      exit
    }

    # This route serves the built-in images for not_found and exceptions.
    get "/__kemal__/:image" do |env|
      image = env.params.url["image"]
      file_path = File.expand_path("libs/kemal/images/#{image}", Dir.current)
      if File.exists? file_path
        env.response.headers.add "Content-Type", "application/octet-stream"
        env.response.content_length = File.size(file_path)
        File.open(file_path) do |file|
          IO.copy(file, env.response)
        end
      end
    end

    config.logger.write "[#{config.env}] Kemal is ready to lead at #{config.scheme}://#{config.host_binding}:#{config.port}\n"
    server.listen
  end
end

at_exit do
  Kemal.run if Kemal.config.run
end
