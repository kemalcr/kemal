class HTTP::Server::Response
  # Returns `true` if the response headers have already been written to the
  # client. Once the headers are sent, the status code and headers can no
  # longer be modified.
  def headers_sent? : Bool
    wrote_headers?
  end

  # Drops whatever body has been written but not yet sent, so that an error page
  # replaces it instead of following it. A body is buffered until the headers go
  # out, so this is possible exactly while `headers_sent?` is false; once they
  # have gone the body is on the wire and the caller has nothing left to decide.
  # Returns whether the body could be discarded.
  def discard_unsent_body : Bool
    return false if headers_sent?

    case output = @output
    when Output
      output.reset
    when Kemal::HeadRequestHandler::NullIO
      output.reset
    end
    true
  end

  # This override collides with the new stdlib of Crystal 1.3
  # See https://github.com/kemalcr/kemal/issues/627 for more details
  {% if compare_versions(Crystal::VERSION, "1.3.0") < 0 %}
    class Output
      def close
        unless response.wrote_headers? && !response.headers.has_key?("Content-Range")
          response.content_length = @out_count
        end

        ensure_headers_written

        previous_def
      end
    end
  {% end %}
end
