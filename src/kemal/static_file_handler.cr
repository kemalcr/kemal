module Kemal
  class StaticFileHandler < HTTP::StaticFileHandler
    private DEFAULT_MEMORY_CACHE_SIZE = 8_i64 * 1024 * 1024
    private record CachedFile, data : Bytes, file_info : File::Info

    @cached_files = {} of String => CachedFile
    @cached_bytes = 0_i64
    @cache_lock = Mutex.new

    private def serve_static_asset(context : HTTP::Server::Context, file_path : String, file_info : File::Info, mime_path : String = file_path)
      last_modified = file_info.modification_time
      add_cache_headers(context.response.headers, last_modified)

      if cache_request?(context, last_modified)
        context.response.status = :not_modified
        return
      end

      mime_type = MIME.from_filename(mime_path, "application/octet-stream")
      if cached = cached_file(file_path, file_info)
        send_file(context, file_path, cached.data, cached.file_info, mime_type)
      else
        send_file(context, file_path, mime_type)
      end
    end

    private def cached_file(file_path : String, file_info : File::Info) : CachedFile?
      cache_limit = memory_cache_limit
      return if cache_limit <= 0
      return if file_info.size > cache_limit

      cached = nil
      @cache_lock.synchronize do
        if entry = @cached_files[file_path]?
          if fresh_cache_entry?(entry, file_info)
            cached = entry
          else
            remove_cached_file(file_path, entry)
          end
        end
      end
      return cached if cached

      data = read_file_bytes(file_path, file_info.size)
      return unless data

      stored = nil
      data_size = data.bytesize.to_i64
      @cache_lock.synchronize do
        if entry = @cached_files[file_path]?
          if fresh_cache_entry?(entry, file_info)
            stored = entry
          else
            remove_cached_file(file_path, entry)
          end
        end

        unless stored
          if @cached_bytes + data_size <= cache_limit
            stored = CachedFile.new(data, file_info)
            @cached_files[file_path] = stored.not_nil!
            @cached_bytes += data_size
          end
        end
      end

      stored
    end

    private def memory_cache_limit : Int64
      cache_size = Kemal.config.serve_static_size_option("cache_size")
      return cache_size if cache_size.positive?
      return DEFAULT_MEMORY_CACHE_SIZE if Kemal.config.serve_static_option?("cache")

      0_i64
    end

    private def fresh_cache_entry?(entry : CachedFile, file_info : File::Info) : Bool
      cached_info = entry.file_info
      cached_info.size == file_info.size && cached_info.modification_time == file_info.modification_time
    end

    private def remove_cached_file(file_path : String, entry : CachedFile)
      @cached_files.delete(file_path)
      @cached_bytes -= entry.data.bytesize.to_i64
    end

    private def read_file_bytes(file_path : String, size : Int64) : Bytes?
      data = Bytes.new(size.to_i)
      File.open(file_path) do |file|
        file.read_fully(data)
      end
      data
    rescue File::Error
      nil
    end

    {% if compare_versions(Crystal::VERSION, "1.17.0") >= 0 %}
      private def directory_index(context : HTTP::Server::Context, request_path : Path, file_path : Path)
        config = Kemal.config
        unless config.serve_static.is_a?(Hash)
          return call_next(context)
        end

        index_path = file_path / "index.html"
        if config.serve_static_option?("dir_index") && (index_info = File.info?(index_path))
          serve_static_asset(context, index_path.to_s, index_info)
        elsif config.serve_static_option?("dir_listing")
          context.response.content_type = "text/html; charset=utf-8"
          directory_listing(context.response, request_path, file_path)
        else
          call_next(context)
        end
      end

      private def serve_file(context : HTTP::Server::Context, file_info, file_path : Path, original_file_path : Path, last_modified : Time)
        serve_static_asset(context, file_path.to_s, file_info, original_file_path.to_s)
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
          config = Kemal.config

          if config.serve_static.is_a?(Hash) && config.serve_static_option?("dir_index") && File.exists?(File.join(file_path, "index.html"))
            file_path = File.join(@public_dir, expanded_path, "index.html")
            serve_static_asset(context, file_path, File.info(file_path))
          elsif config.serve_static.is_a?(Hash) && config.serve_static_option?("dir_listing")
            context.response.content_type = "text/html; charset=utf-8"
            directory_listing(context.response, request_path, file_path)
          else
            call_next(context)
          end
        elsif is_file
          serve_static_asset(context, file_path.to_s, file_info)
        else # Not a normal file (FIFO/device/socket)
          call_next(context)
        end
      end
    {% end %}
  end
end
