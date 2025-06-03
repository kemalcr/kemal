module Kemal
  class StaticFileHandler < HTTP::StaticFileHandler
    {% if compare_versions(Crystal::VERSION, "1.17.0") >= 0 %}
      private def directory_index(context : HTTP::Server::Context, request_path : Path, file_path : Path)
        config = Kemal.config.serve_static
        unless config.is_a?(Hash)
          return call_next(context)
        end

        index_path = file_path / "index.html"
        if config.fetch("dir_index", false) && (index_info = File.info?(index_path))
          last_modified = index_info.modification_time
          add_cache_headers(context.response.headers, last_modified)

          if cache_request?(context, last_modified)
            context.response.status = :not_modified
            return
          end

          send_file(context, index_path.to_s)
        elsif config.fetch("dir_listing", false)
          context.response.content_type = "text/html; charset=utf-8"
          directory_listing(context.response, request_path, file_path)
        else
          call_next(context)
        end
      end

      # NOTE: This override opts out of some behaviour from HTTP::StaticFileHandler,
      # such as serving content ranges.
      private def serve_file(context : HTTP::Server::Context, file_info, file_path : Path, original_file_path : Path, last_modified : Time)
        send_file(context, file_path.to_s)
      end
    {% else %}
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

        original_path = context.request.path.not_nil!
        is_dir_path = original_path.ends_with?("/")
        request_path = URI.decode(original_path)

        # File path cannot contains '\0' (NUL) because all filesystem I know
        # don't accept '\0' character as file name.
        if request_path.includes? '\0'
          context.response.respond_with_status(:bad_request)
          return
        end

        request_path = Path.posix(request_path)
        expanded_path = request_path.expand("/")

        file_path = @public_dir.join(expanded_path.to_kind(Path::Kind.native))
        file_info = File.info? file_path
        is_dir = @directory_listing && file_info && file_info.directory?
        is_file = file_info && file_info.file?

        if request_path != expanded_path || is_dir && !is_dir_path
          redirect_path = expanded_path
          if is_dir && !is_dir_path
            # Append / to path if missing
            redirect_path = expanded_path.join("")
          end
          redirect_to context, redirect_path
          return
        end

        return call_next(context) unless file_info

        if is_dir
          config = Kemal.config.serve_static

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
        elsif is_file
          last_modified = modification_time(file_path)
          add_cache_headers(context.response.headers, last_modified)

          if cache_request?(context, last_modified)
            context.response.status_code = 304
            return
          end
          send_file(context, file_path.to_s)
        else # Not a normal file (FIFO/device/socket)
          call_next(context)
        end
      end

      private def modification_time(file_path)
        File.info(file_path).modification_time
      end
    {% end %}
  end
end
