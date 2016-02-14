require "colorize"
require "http"

class Kemal::CommonLogHandler < Kemal::BaseLogHandler
  getter handler

  def initialize(@env)
    @handler = if @env == "production"
                 handler = File.new("kemal.log", "a")
                 handler.flush_on_newline = true
                 handler
               else
                 STDOUT
               end
  end

  def call(context)
    time = Time.now
    call_next(context)
    elapsed = Time.now - time
    elapsed_text = elapsed_text(elapsed)

    if @env == "production"
      status_code = " #{context.response.status_code} "
      method = context.request.method
    else
      statusColor = color_for_status(context.response.status_code)
      methodColor = color_for_method(context.request.method)

      status_code = " #{context.response.status_code} ".colorize.back(statusColor).fore(:white)
      method = context.request.method.colorize(methodColor)
    end

    output_message = "#{time} |#{status_code}| #{method} #{context.request.resource} - #{elapsed_text}\n"
    write output_message
    context
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

  def write(message)
    if @env == "production"
      @handler.write message.to_slice
    else
      @handler.print message
    end
  end

  private def color_for_status(code)
    if code >= 200 && code < 300
      return :green
    elsif code >= 300 && code < 400
      return :magenta
    elsif code >= 400 && code < 500
      return :yellow
    else
      return :light_blue
    end
  end

  private def color_for_method(method)
    case method
    when "GET"
      return :blue
    when "POST"
      return :cyan
    when "PUT"
      return :yellow
    when "DELETE"
      return :red
    when "PATCH"
      return :green
    when "HEAD"
      return :magenta
    when "OPTIONS"
      return :light_blue
    else
      return :white
    end
  end
end
