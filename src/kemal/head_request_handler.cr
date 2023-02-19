require "http/server/handler"

module Kemal
  class HeadRequestHandler
    include HTTP::Handler

    INSTANCE = new

    private class NullIO < IO
      @original_output : IO
      @out_count : Int32
      @response : HTTP::Server::Response

      def initialize(@response)
        @closed = false
        @original_output = @response.output
        @out_count = 0
      end

      def read(slice : Bytes)
        raise NotImplementedError.new("read")
      end

      def write(slice : Bytes) : Nil
        @out_count += slice.bytesize
      end

      def close : Nil
        return if @closed
        @closed = true

        # Matching HTTP::Server::Response#close behavior:
        # Conditionally determine based on status if the `content-length` header should be added automatically.
        # See https://tools.ietf.org/html/rfc7230#section-3.3.2.
        status = @response.status
        set_content_length = !(status.not_modified? || status.no_content? || status.informational?)

        if !@response.headers.has_key?("Content-Length") && set_content_length
          @response.content_length = @out_count
        end

        @original_output.close
      end

      def closed? : Bool
        @closed
      end
    end

    def call(context) : Nil
      if context.request.method == "HEAD"
        # Capture and count bytes of response body generated on HEAD requests without actually sending the body back.
        capture_io = NullIO.new(context.response)
        context.response.output = capture_io
      end

      call_next(context)
    end
  end
end
