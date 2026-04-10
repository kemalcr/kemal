module Kemal
  # :nodoc:
  # Wraps a request body `IO` and raises `Exceptions::PayloadTooLarge` once the
  # total number of bytes read (via read, skip, peek consumption paths, etc.)
  # would exceed *max_bytes*. Used for multipart parsing when `Content-Length`
  # is absent (e.g. chunked encoding).
  class BoundedTotalBodyIO < IO
    def initialize(@io : IO, @max_bytes : Int32)
      @total_read = 0
    end

    def read(slice : Bytes) : Int32
      return 0 if slice.empty?

      remaining = @max_bytes - @total_read
      raise Exceptions::PayloadTooLarge.new if remaining <= 0

      to_read = Math.min(slice.size, remaining)
      count = @io.read(slice[0, to_read])
      @total_read += count
      count
    end

    def peek : Bytes?
      remaining = @max_bytes - @total_read
      return Bytes.empty if remaining <= 0

      inner = @io.peek
      return unless inner
      return Bytes.empty if inner.empty?

      if inner.size > remaining
        inner[0, remaining]
      else
        inner
      end
    end

    def write(slice : Bytes) : Nil
      raise IO::Error.new("Can't write to BoundedTotalBodyIO")
    end
  end
end
