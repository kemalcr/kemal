module Kemal
  # This is here to represent the logger corresponding to Null Object Pattern.
  class NullLogHandler < Kemal::BaseLogHandler
    def call(context)
    end

    def write(message)
    end
  end
end
