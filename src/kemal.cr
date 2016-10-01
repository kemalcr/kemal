require "http"
require "multipart"
require "./kemal/*"
require "./kemal/helpers/*"
require "./kemal/middleware/*"

module Kemal
  # The command to run a `Kemal` application.
  # The port can be given to `#run` but is optional.
  # If not given Kemal will use `Kemal::Config#port`
  def self.run(port = nil)
    Kemal::CLI.new
    config = Kemal.config
    config.setup
    config.add_handler Kemal::RouteHandler::INSTANCE
    config.port = port if port

    config.server = HTTP::Server.new(config.host_binding, config.port, config.handlers)
    {% if !flag?(:without_openssl) %}
    config.server.tls = config.ssl
    {% end %}

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
        config.server.close
        exit
      }

      # This route serves the built-in images for not_found and exceptions.
      get "/__kemal__/:image" do |env|
        image = env.params.url["image"]
        file_path = File.expand_path("libs/kemal/images/#{image}", Dir.current)
        if File.exists? file_path
          send_file env, file_path
        end
      end

      config.logger.write "[#{config.env}] Kemal is ready to lead at #{config.scheme}://#{config.host_binding}:#{config.port}\n"
      config.server.listen
    end
  end
end
