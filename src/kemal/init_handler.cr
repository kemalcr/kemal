module Kemal
  # Initializes the context with default values, such as
  # *Content-Type* or *X-Powered-By* headers.
  class InitHandler
    include HTTP::Handler

    getter app : Kemal::Base

    def initialize(@app)
    end

    def call(context : HTTP::Server::Context)
      context.response.headers.add "X-Powered-By", "Kemal"
      context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
      context.app = app
      call_next context
    end
  end
end
