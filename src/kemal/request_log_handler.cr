module Kemal
  # :nodoc:
  class RequestLogHandler
    include HTTP::Handler

    def call(context : HTTP::Server::Context)
      elapsed_time = Time.measure { call_next(context) }
      elapsed_text = elapsed_text(elapsed_time)
      Log.info { "#{context.response.status_code} #{context.request.method} #{context.request.resource} #{elapsed_text}" }
      context
    end

    private def elapsed_text(elapsed)
      millis = elapsed.total_milliseconds
      return "#{millis.round(2)}ms" if millis >= 1

      "#{(millis * 1000).round(2)}µs"
    end
  end
end
