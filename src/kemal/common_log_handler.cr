require "http"

class Kemal::CommonLogHandler < Kemal::BaseLogHandler
  @handler : IO::FileDescriptor
  getter handler

  def initialize
    @handler = STDOUT
  end

  def call(context)
    time = Time.now
    call_next(context)
    elapsed_text = elapsed_text(Time.now - time)
    @handler << time << " " << context.response.status_code << " " << context.request.method << " " << context.request.resource << " " << elapsed_text << "\n"
    context
  end

  def write(message)
    @handler << message
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
