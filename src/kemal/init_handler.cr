module Kemal
  # Kemal::InitHandler is the first handler thus initializes the context with default values such as
  # Content-Type, X-Powered-By.
  class InitHandler < HTTP::Handler
    INSTANCE = new

    def call(context)
      context.response.headers.add "X-Powered-By", "Kemal"
      context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
      call_next context
    end
  end
end
