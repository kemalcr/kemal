# This override collides with the new stdlib of Crystal 1.3
# See https://github.com/kemalcr/kemal/issues/627 for more details
{{ skip_file if compare_versions(Crystal::VERSION, "1.3.0") >= 0 }}

class HTTP::Server::Response
  class Output
    def close
      # ameba:disable Style/NegatedConditionsInUnless
      unless response.wrote_headers? && !response.headers.has_key?("Content-Range")
        response.content_length = @out_count
      end

      ensure_headers_written

      previous_def
    end
  end
end
