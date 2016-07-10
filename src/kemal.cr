require "./kemal/*"
require "./kemal/helpers/*"
require "./kemal/middleware/*"

module Kemal
  # The command to run a `Kemal` application.
  def self.run
    Kemal::CLI.new
    config = Kemal.config
    config.setup
    config.add_handler Kemal::RouteHandler::INSTANCE

    config.server = HTTP::Server.new(config.host_binding.not_nil!, config.port, config.handlers)
    config.server.not_nil!.tls = config.ssl

    Kemal::Sessions.run_reaper!

    unless Kemal.config.error_handlers.has_key?(404)
      error 404 do |env|
        render_404
      end
    end

    # Test environment doesn't need to have signal trap, built-in images, and logging.
    unless config.env == "test"
      Signal::INT.trap {
        config.logger.write "Kemal is going to take a rest!\n"
        config.server.not_nil!.close
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
      config.server.not_nil!.listen
    end
  end
end
