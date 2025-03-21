module Kemal
  # This is here to represent the logger corresponding to Null Object Pattern.
  @[Deprecated("Use standard library Log")]
  class NullLogHandler < Kemal::BaseLogHandler
    def call(context : HTTP::Server::Context)
      call_next(context)
    end

    def write(message : String)
    end
  end
end
