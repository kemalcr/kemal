require "http"
require "./kemal/*"
require "./kemal/helpers/*"

# This is literally `hack` to fix [Crystal issue #4060](https://github.com/crystal-lang/crystal/issues/4060)
class Gzip::Header
  def to_io(io)
    # header
    io.write_byte ID1
    io.write_byte ID2

    # compression method
    io.write_byte DEFLATE

    # flg
    flg = Flg::None
    flg |= Flg::EXTRA if !@extra.empty?
    flg |= Flg::NAME if @name
    flg |= Flg::COMMENT if @comment
    io.write_byte flg.value

    # time
    io.write_bytes(modification_time.epoch.to_u32, IO::ByteFormat::LittleEndian)

    # xfl
    io.write_byte 0_u8

    # os
    io.write_byte os

    if !@extra.empty?
      io.write_byte @extra.size.to_u8
      io.write(@extra)
    end

    if name = @name
      io << name
      io.write_byte 0_u8
    end

    if comment = @comment
      io << comment
      io.write_byte 0_u8
    end
  end
end

module Kemal
  # Overload of self.run with the default startup logging
  def self.run(port = nil)
    self.run port do
      log "[#{config.env}] Kemal is ready to lead at #{config.scheme}://#{config.host_binding}:#{config.port}\n"
    end
  end

  # Overload of self.run to allow just a block
  def self.run(&block)
    self.run nil, &block
  end

  # The command to run a `Kemal` application.
  # The port can be given to `#run` but is optional.
  # If not given Kemal will use `Kemal::Config#port`
  def self.run(port = nil, &block)
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
        log "Kemal is going to take a rest!\n" if config.shutdown_message
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
    end

    config.running = true
    yield config
    config.server.listen if config.env != "test"
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
