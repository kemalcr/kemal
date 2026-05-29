module Kemal
  # Helper for Server-Sent Events (SSE) responses.
  #
  # Sets the required headers and formats events according to the SSE spec.
  class EventStream
    def initialize(@response : HTTP::Server::Response)
      setup_headers
    end

    # Runs an SSE handler with headers configured and yields an `EventStream`.
    def self.serve(context : HTTP::Server::Context, &block : EventStream, HTTP::Server::Context ->)
      stream = new(context.response)
      yield stream, context
      stream
    end

    # Sends an SSE event. Multi-line *data* is split into separate `data:` fields.
    def send(data : String, *, event : String? = nil, id : String | Int? = nil, retry : Int32? = nil) : self
      @response.print "event: #{event}\n" if event
      @response.print "id: #{id}\n" if id
      @response.print "retry: #{retry}\n" if retry
      data.each_line(chomp: true) do |line|
        @response.print "data: #{line}\n"
      end
      @response.print "\n"
      flush
      self
    end

    # Sends a keep-alive comment (ignored by clients, useful during idle periods).
    def comment(text : String) : self
      @response.print ": #{text}\n\n"
      flush
      self
    end

    def flush : Nil
      @response.flush
    end

    def close : Nil
      @response.close
    end

    private def setup_headers
      @response.content_type = "text/event-stream; charset=utf-8"
      @response.headers["Cache-Control"] = "no-cache"
      unless @response.headers.has_key?("Connection")
        @response.headers["Connection"] = "keep-alive"
      end
    end
  end
end
