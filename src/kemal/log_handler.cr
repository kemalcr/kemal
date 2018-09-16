module Kemal
  # Uses `STDOUT` by default and handles the logging of request/response process time.
  class LogHandler < Kemal::BaseLogHandler
    def initialize(@io : IO = STDOUT)
    end

    def call(context : HTTP::Server::Context)
      time = Time.now
      call_next(context)
      elapsed_text = elapsed_text(Time.now - time)
      @io << time << ' ' << context.response.status_code << ' ' << context.request.method << ' ' << context.request.resource << ' ' << elapsed_text << '\n'
      context
    end

    def write(message : String)
      @io << message
    end

    private def elapsed_text(elapsed)
      millis = elapsed.total_milliseconds
      return "#{millis.round(2)}ms" if millis >= 1

      "#{(millis * 1000).round(2)}µs"
    end
  end
end
