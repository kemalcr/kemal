class Kemal::Logger < HTTP::Handler
  getter handler

  def initialize
    @env = Kemal.config.env
    @handler = STDOUT
    config = Kemal.config
    @startup_message = "Kemal is ready to lead at #{config.scheme}://0.0.0.0:#{config.port}"
    @env == "production" ? setup_file_handler : setup_stdout_handler
  end

  def call(request)
    time = Time.now
    response = call_next(request)
    elapsed = Time.now - time
    elapsed_text = elapsed_text(elapsed)
    output_message = "#{request.method} #{request.resource} - #{response.status_code} (#{elapsed_text})\n"
    @handler.print output_message if @env == "development"
    @handler.write output_message.to_slice if @env == "production"
    response
  end

  private def elapsed_text(elapsed)
    minutes = elapsed.total_minutes
    return "#{minutes.round(2)}m" if minutes >= 1

    seconds = elapsed.total_seconds
    return "#{seconds.round(2)}s" if seconds >= 1

    millis = elapsed.total_milliseconds
    return "#{millis.round(2)}ms" if millis >= 1

    "#{(millis * 1000).round(2)}µs"
  end

  private def setup_file_handler
    @handler = File.new("kemal.log", "a+")
    @handler.write @startup_message.to_slice
  end

  private def setup_stdout_handler
    @handler.print @startup_message
  end
end
