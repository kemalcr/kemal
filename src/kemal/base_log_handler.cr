require "http"

class Kemal::BaseLogHandler < HTTP::Handler

  def initialize(@env)
  end

  def call(context)
  end

  def write(message)
  end
end
