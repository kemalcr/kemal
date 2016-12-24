module Kemal
  # All loggers must inherit from `Kemal::BaseLogHandler`.
  abstract class Kemal::BaseLogHandler
    include HTTP::Handler

    abstract def call(context)
    abstract def write(message)
  end
end
