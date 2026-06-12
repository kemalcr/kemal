class HTTP::Server::Response
  # Returns `true` if the response headers have already been written to the
  # client. Once the headers are sent, the status code and headers can no
  # longer be modified.
  def headers_sent? : Bool
    wrote_headers?
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
