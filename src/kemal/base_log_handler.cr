require "http"

# All loggers must inherit from `Kemal::BaseLogHandler`.
class Kemal::BaseLogHandler < HTTP::Handler
  def initialize
  end

  def call(context)
    call_next context
  end

  def write(message)
  end
end
