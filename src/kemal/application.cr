class Kemal::Application < Kemal::Base
  def initialize(config = Config.default)
    super(config)
  end

  # Overload of self.run with the default startup logging
  def run(port = nil)
    run port do
      log "[#{config.env}] Kemal is ready to lead at #{config.scheme}://#{config.host_binding}:#{port || config.port}"
    end
  end

  private def prepare_for_server_start
    super

    unless error_handlers.has_key?(404)
      self.error 404 do |env|
        render_404
      end
    end

    # Test environment doesn't need to have signal trap and built-in images.
    unless @config.env == "test"
      Signal::INT.trap do
        log "Kemal is going to take a rest!" if @config.shutdown_message?
        stop if running?
        exit
      end

      # This route serves the built-in images for not_found and exceptions.
      self.get "/__kemal__/:image" do |env|
        image = env.params.url["image"]
        file_path = File.expand_path("lib/kemal/images/#{image}", Dir.current)
        if File.exists? file_path
          send_file env, file_path
        else
          halt env, 404
        end
      end
    end
  end
end
