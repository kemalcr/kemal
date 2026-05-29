module Kemal
  # Helper for Server-Sent Events (SSE) responses.
  #
  # Sets the required headers and formats events according to the SSE spec.
  class EventStream
    def initialize(@response : HTTP::Server::Response)
      setup_headers
    end

    # Runs an SSE handler with headers configured and yields an `EventStream`.
    def self.serve(context : HTTP::Server::Context, & : EventStream, HTTP::Server::Context ->)
      stream = new(context.response)
      yield stream, context
      stream
    end

    # Sends an SSE event. Multi-line *data* is split into separate `data:` fields.
    def send(data : String, *, event : String? = nil, id : String | Int? = nil, retry : Time::Span? = nil) : self
      @response.puts "event: #{event}" if event
      @response.puts "id: #{id}" if id
      @response.puts "retry: #{retry.total_milliseconds.to_i}" if retry
      data.each_line(chomp: true) do |line|
        @response.puts "data: #{line}"
      end
      @response.puts
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
      @response.headers["X-Accel-Buffering"] = "no"
      unless @response.headers.has_key?("Connection")
        @response.headers["Connection"] = "keep-alive"
      end
    end
  end
end
