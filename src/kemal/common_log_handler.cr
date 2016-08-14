module Kemal
  # Kemal::CommonLogHandler uses STDOUT by default and handles the logging of request/response process time.
  # It's also provides a `write` method for common logging purposes.
  class CommonLogHandler < Kemal::BaseLogHandler
    @handler : IO

    def initialize(io : IO = STDOUT)
      @handler = io
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
      millis = elapsed.total_milliseconds
      return "#{millis.round(2)}ms" if millis >= 1

      "#{(millis * 1000).round(2)}µs"
    end
  end
end
