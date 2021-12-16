module Kemal
  module Helpers
    module Runner
      macro included
        extend ClassMethods
      end

      # Overload of `run` with the default startup logging.
      def run(port : Int32?, args = ARGV)
        run(port, args) { }
      end

      # Overload of `run` without port.
      def run(args = ARGV)
        run(nil, args: args) { }
      end

      # Overload of `run` to allow just a block.
      def run(args = ARGV)
        run(nil, args: args) do |config|
          yield config
        end
      end

      # The command to run a `Kemal` application.
      #
      # If *port* is not given Kemal will use `Kemal::Config#port`
      #
      # To use custom command line arguments, set args to nil
      #
      def run(port : Int32? = nil, args = ARGV, &block)
        Kemal::CLI.new args, config: config
        config.setup
        config.port = port if port

        # Test environment doesn't need to have signal trap and logging.
        if config.env != "test"
          setup_404
          setup_trap_signal
        end

        server = config.server ||= HTTP::Server.new(config.handlers)

        config.running = true

        yield config

        # Abort if block called `Kemal.stop`
        return unless config.running

        unless server.each_address { |_| break true }
          {% if flag?(:without_openssl) %}
            server.bind_tcp(config.host_binding, config.port)
          {% else %}
            if ssl = config.ssl
              server.bind_tls(config.host_binding, config.port, ssl)
            else
              server.bind_tcp(config.host_binding, config.port)
            end
          {% end %}
        end

        display_startup_message(config, server)

        server.listen unless config.env == "test"
      end

      def stop
        raise "#{config.app_name} is already stopped." if !config.running
        if server = config.server
          server.close unless server.closed?
          config.running = false
        else
          raise "server is not set. Please use Kemal.run to set the server."
        end
      end

      def display_startup_message(config, server)
        addresses = server.addresses.join ", " { |address| "#{config.scheme}://#{address}" }
        log "[#{config.env}] #{config.app_name} is ready to lead at #{addresses}"
      end

      private def setup_404
        unless error_handlers.has_key?(404)
          self.error 404 do
            render_404
          end
        end
      end

      private def setup_trap_signal
        Signal::INT.trap do
          log "#{config.app_name} is going to take a rest!" if config.shutdown_message
          self.stop
          exit
        end
      end

      module ClassMethods
        def run(port : Int32?, args = ARGV)
          new.run(port, args) { }
        end

        def run(args = ARGV)
          new.run(nil, args) { }
        end

        def run(args = ARGV)
          new.run(nil, args) do |config|
            yield config
          end
        end

        def run(port : Int32? = nil, args = ARGV)
          new.run(port, args) do |config|
            yield config
          end
        end
      end
    end
  end
end