module Kemal
  # Helper for Server-Sent Events (SSE) responses.
  #
  # Sets the required headers and formats events according to the SSE spec.
  class EventStream
    # SSE treats CR, LF, and CRLF as line terminators (WHATWG HTML).
    private SSE_LINE_BREAK = /\r\n|\r|\n/

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
    # *event* and *id* must not contain CR/LF; newlines there raise `ArgumentError`
    # so they cannot inject SSE fields.
    def send(data : String, *, event : String? = nil, id : String | Int? = nil, retry : Time::Span? = nil) : self
      if event
        validate_single_line!("event", event)
        @response.puts "event: #{event}"
      end
      if id
        id_value = id.to_s
        validate_single_line!("id", id_value)
        @response.puts "id: #{id_value}"
      end
      @response.puts "retry: #{retry.total_milliseconds.to_i}" if retry
      each_sse_line(data) do |line|
        @response.puts "data: #{line}"
      end
      @response.puts
      flush
      self
    end

    # Sends a keep-alive comment (ignored by clients, useful during idle periods).
    def comment(text : String) : self
      each_sse_line(text) { |line| @response.print ": #{line}\n" }
      @response.print "\n"
      flush
      self
    end

    def flush : Nil
      @response.flush
    end

    def close : Nil
      @response.close
    end

    private def validate_single_line!(field : String, value : String) : Nil
      if value.includes?('\n') || value.includes?('\r')
        raise ArgumentError.new("SSE #{field} must not contain CR or LF")
      end
    end

    # Yields each SSE line. Normalizes CR/CRLF only when needed to avoid an extra alloc.
    private def each_sse_line(value : String, & : String ->) : Nil
      value = value.gsub(SSE_LINE_BREAK, "\n") if value.includes?('\r')
      value.each_line(chomp: true) { |line| yield line }
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
