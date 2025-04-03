module Kemal
  class StaticFileHandler < HTTP::StaticFileHandler
    # ameba:disable Metrics/CyclomaticComplexity
    def call(context : HTTP::Server::Context)
      return call_next(context) if context.request.path.not_nil! == "/"

      case context.request.method
      when "GET", "HEAD"
      else
        if @fallthrough
          call_next(context)
        else
          context.response.status_code = 405
          context.response.headers.add("Allow", "GET, HEAD")
        end
        return
      end

      config = Kemal.config.serve_static
      original_path = context.request.path.not_nil!
      request_path = URI.decode(original_path)

      # File path cannot contains '\0' (NUL) because all filesystem I know
      # don't accept '\0' character as file name.
      if request_path.includes? '\0'
        context.response.status_code = 400
        return
      end

      # Check for directory traversal attacks
      if request_path.includes? ".."
        context.response.status_code = 400
        return
      end

      expanded_path = request_path
      is_dir_path = if original_path.ends_with?('/') && !expanded_path.ends_with? '/'
                      expanded_path = expanded_path + '/'
                      true
                    else
                      expanded_path.ends_with? '/'
                    end

      file_path = File.join(@public_dir, expanded_path)
      is_dir = Dir.exists?(file_path)

      if request_path != expanded_path
        redirect_to context, expanded_path
        return
      elsif is_dir && !is_dir_path
        redirect_to context, expanded_path + '/'
        return
      end

      if is_dir
        if config.is_a?(Hash) && config.fetch("dir_index", false) && File.exists?(File.join(file_path, "index.html"))
          file_path = File.join(@public_dir, expanded_path, "index.html")

          last_modified = modification_time(file_path)
          add_cache_headers(context.response.headers, last_modified)

          if cache_request?(context, last_modified)
            context.response.status_code = 304
            return
          end
          send_file(context, file_path)
        elsif config.is_a?(Hash) && config.fetch("dir_listing", false)
          context.response.content_type = "text/html; charset=utf-8"
          directory_listing(context.response, request_path, file_path)
        else
          call_next(context)
        end
      elsif File.exists?(file_path)
        last_modified = modification_time(file_path)
        add_cache_headers(context.response.headers, last_modified)

        if cache_request?(context, last_modified)
          context.response.status_code = 304
          return
        end
        send_file(context, file_path)
      else
        call_next(context)
      end
    end

    private def modification_time(file_path)
      File.info(file_path).modification_time
    end

    # Sanitizes the path to prevent directory traversal attacks
    private def sanitize_path(path : String) : String?
      # Remove any leading or trailing slashes
      path = path.strip('/')

      # Split the path into components
      components = path.split('/')

      # Filter out empty components and normalize the path
      normalized_components = components.reject(&.empty?)

      # Check for any directory traversal attempts
      # Only reject paths that explicitly try to traverse up directories
      return nil if normalized_components.any? { |component| component == ".." }

      # Reconstruct the path
      normalized_components.join('/')
    end
  end
end
