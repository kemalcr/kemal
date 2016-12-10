require "http"
require "multipart"
require "./kemal/*"
require "./kemal/helpers/*"

module Kemal
  # The command to run a `Kemal` application.
  # The port can be given to `#run` but is optional.
  # If not given Kemal will use `Kemal::Config#port`
  def self.run(port = nil)
    Kemal::CLI.new
    config = Kemal.config
    config.setup
    config.port = port if port

    config.server = HTTP::Server.new(config.host_binding, config.port, config.handlers)
    {% if !flag?(:without_openssl) %}
    config.server.tls = config.ssl
    {% end %}

    unless Kemal.config.error_handlers.has_key?(404)
      error 404 do |env|
        render_404
      end
    end

    # Test environment doesn't need to have signal trap, built-in images, and logging.
    unless config.env == "test"
      Signal::INT.trap {
        log "Kemal is going to take a rest!\n"
        Kemal.stop
        exit
      }

      # This route serves the built-in images for not_found and exceptions.
      get "/__kemal__/:image" do |env|
        image = env.params.url["image"]
        file_path = File.expand_path("lib/kemal/images/#{image}", Dir.current)
        if File.exists? file_path
          send_file env, file_path
        else
          halt env, 404
        end
      end

      log "[#{config.env}] Kemal is ready to lead at #{config.scheme}://#{config.host_binding}:#{config.port}\n"
      config.running = true
      config.server.listen
    end
  end

  def self.stop
    if config.running
      if config.server
        config.server.close
        config.running = false
      else
        raise "Kemal.config.server is not set. Please use Kemal.run to set the server."
      end
    else
      raise "Kemal is already stopped."
    end
  end
end
