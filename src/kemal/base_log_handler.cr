module Kemal
  # All loggers must inherit from `Kemal::BaseLogHandler`.
  abstract class Kemal::BaseLogHandler < HTTP::Handler
    abstract def call(context)
    abstract def write(message)
  end
end
