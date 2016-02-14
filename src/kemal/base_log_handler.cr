require "http"

class Kemal::BaseLogHandler < HTTP::Handler
  def initialize(@env)
  end

  def call(context)
    call_next context
  end

  def write(message)
  end
end
