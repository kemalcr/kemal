module Kemal
  # Provides a way to log request information.
  #
  # See `Kemal::Config#request_logger=` for more information.
  alias RequestLogger = Proc(HTTP::Server::Context, String, String)

  # :nodoc:
  class RequestLogHandler
    include HTTP::Handler

    setter request_logger : RequestLogger

    def initialize(request_logger : RequestLogger? = nil)
      request_logger ||= RequestLogger.new do |context, elapsed_time|
        "#{context.response.status_code} #{context.request.method} #{context.request.resource} #{elapsed_time}"
      end
      @request_logger = request_logger
    end

    def call(context : HTTP::Server::Context)
      elapsed_time = Time.measure { call_next(context) }
      elapsed_text = elapsed_text(elapsed_time)
      Log.info { @request_logger.call(context, elapsed_text) }
      context
    end

    private def elapsed_text(elapsed)
      millis = elapsed.total_milliseconds
      return "#{millis.round(2)}ms" if millis >= 1

      "#{(millis * 1000).round(2)}µs"
    end
  end
end
