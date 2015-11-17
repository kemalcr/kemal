class Kemal::Logger < HTTP::Handler
  property handler

  def initialize
    @env = Kemal.config.env
    if @env == "production"
      @handler = File.new("kemal.log", "a+")
    else
      @handler = STDOUT
    end
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
end
