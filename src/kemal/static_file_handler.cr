module Kemal
  class StaticFileHandler < HTTP::StaticFileHandler
    private DEFAULT_MEMORY_CACHE_SIZE    = 8_i64 * 1024 * 1024
    private DEFAULT_CACHE_CHECK_INTERVAL = 1_000_i64
    private record CachedFile, data : Bytes, file_info : File::Info, checked_at : Time::Instant

    @cached_files = {} of String => CachedFile
    @cached_bytes = 0_i64
    @cache_lock = Mutex.new

    private record RequestTarget, original_path : String, request_path : Path, expanded_path : Path, file_path : Path, is_dir_path : Bool

    def call(context : HTTP::Server::Context)
      original_path = context.request.path
      return call_next(context) unless original_path
      return call_next(context) if original_path == "/"

      target = request_target(context, original_path)
      return unless target
      return unless allow_request_method?(context)
      return if try_serve_cached_asset(context, target)

      serve_from_disk_or_fallthrough(context, target)
    end

    private def request_target(context : HTTP::Server::Context, original_path : String) : RequestTarget?
      is_dir_path = original_path.ends_with?("/")
      decoded_path = URI.decode(original_path)

      # File path cannot contains '\0' (NUL) because all filesystem I know
      # don't accept '\0' character as file name.
      if decoded_path.includes? '\0'
        context.response.respond_with_status(:bad_request)
        return
      end

      request_path = Path.posix(decoded_path)
      expanded_path = request_path.expand("/")
      if request_path != expanded_path
        redirect_to context, expanded_path
        return
      end

      file_path = @public_dir.join(expanded_path.to_kind(Path::Kind.native))
      RequestTarget.new(original_path, request_path, expanded_path, file_path, is_dir_path)
    end

    private def allow_request_method?(context : HTTP::Server::Context) : Bool
      return true if context.request.method.in?("GET", "HEAD")

      if @fallthrough
        call_next(context)
      else
        context.response.status_code = 405
        context.response.headers.add("Allow", "GET, HEAD")
      end

      false
    end

    private def try_serve_cached_asset(context : HTTP::Server::Context, target : RequestTarget) : Bool
      force_revalidate = conditional_cache_request?(context)

      if !target.is_dir_path
        if cached = cached_file(target.file_path.to_s, force_revalidate)
          serve_cached_asset(context, target.file_path.to_s, cached)
          return true
        end
      elsif cacheable_directory_index?
        index_path = (target.file_path / "index.html").to_s
        if cached = cached_file(index_path, force_revalidate)
          serve_cached_asset(context, index_path, cached)
          return true
        end
      end

      false
    end

    private def conditional_cache_request?(context : HTTP::Server::Context) : Bool
      !!context.request.if_none_match || !!context.request.headers["If-Modified-Since"]?
    end

    private def serve_from_disk_or_fallthrough(context : HTTP::Server::Context, target : RequestTarget)
      file_info = File.info?(target.file_path)
      return call_next(context) unless file_info

      if file_info.directory? && !target.is_dir_path
        redirect_to context, target.expanded_path.join("")
        return
      end

      if file_info.directory?
        serve_directory(context, target)
      elsif file_info.file?
        serve_static_asset(context, target.file_path.to_s, file_info)
      else
        call_next(context)
      end
    end

    private def serve_directory(context : HTTP::Server::Context, target : RequestTarget)
      if cacheable_directory_index?
        index_path = target.file_path / "index.html"
        if index_info = File.info?(index_path)
          serve_static_asset(context, index_path.to_s, index_info)
          return
        end
      end

      if directory_listing_enabled?
        context.response.content_type = "text/html; charset=utf-8"
        directory_listing(context.response, target.request_path, target.file_path)
      else
        call_next(context)
      end
    end

    private def cacheable_directory_index? : Bool
      config = Kemal.config
      config.serve_static.is_a?(Hash) && config.serve_static_option?("dir_index")
    end

    private def directory_listing_enabled? : Bool
      config = Kemal.config
      config.serve_static.is_a?(Hash) && config.serve_static_option?("dir_listing")
    end

    private def serve_cached_asset(context : HTTP::Server::Context, file_path : String, cached : CachedFile, mime_path : String = file_path)
      last_modified = cached.file_info.modification_time
      add_static_cache_headers(context.response.headers, cached.file_info)

      if cache_request?(context, last_modified)
        context.response.status = :not_modified
        return
      end

      mime_type = MIME.from_filename(mime_path, "application/octet-stream")
      send_file(context, file_path, cached.data, cached.file_info, mime_type)
    end

    private def serve_static_asset(context : HTTP::Server::Context, file_path : String, file_info : File::Info, mime_path : String = file_path)
      last_modified = file_info.modification_time
      add_static_cache_headers(context.response.headers, file_info)

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

    private def cached_file(file_path : String, force_revalidate : Bool = false) : CachedFile?
      return unless cache_enabled?

      entry = @cache_lock.synchronize do
        @cached_files[file_path]?
      end
      return unless entry
      return revalidate_cached_file(file_path) if force_revalidate
      return entry unless cache_check_due?(entry)

      revalidate_cached_file(file_path)
    end

    private def cached_file(file_path : String, file_info : File::Info) : CachedFile?
      cache_limit = memory_cache_limit
      return if cache_limit <= 0
      return if file_info.size > cache_limit

      cached = nil
      @cache_lock.synchronize do
        if entry = @cached_files[file_path]?
          if fresh_cache_entry?(entry, file_info)
            cached = refresh_cached_file(file_path, entry)
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
            stored = refresh_cached_file(file_path, entry)
          else
            remove_cached_file(file_path, entry)
          end
        end

        unless stored
          if cache_capacity_available?(data_size, cache_limit)
            cached_file = CachedFile.new(data, file_info, Time.instant)
            stored = cached_file
            @cached_files[file_path] = cached_file
            @cached_bytes += data_size
          end
        end
      end

      stored
    end

    private def revalidate_cached_file(file_path : String) : CachedFile?
      file_info = File.info?(file_path)
      refreshed = nil

      @cache_lock.synchronize do
        if entry = @cached_files[file_path]?
          if file_info && fresh_cache_entry?(entry, file_info)
            refreshed = refresh_cached_file(file_path, entry)
          else
            remove_cached_file(file_path, entry)
          end
        end
      end

      refreshed
    end

    private def memory_cache_limit : Int64
      if cache_size = Kemal.config.serve_static_size_option?("cache_size")
        return cache_size.positive? ? cache_size : 0_i64
      end

      return DEFAULT_MEMORY_CACHE_SIZE if Kemal.config.serve_static_option?("cache")

      0_i64
    end

    private def cache_check_interval : Time::Span
      interval = Kemal.config.serve_static_size_option?("cache_check_interval") || DEFAULT_CACHE_CHECK_INTERVAL
      interval = 0_i64 if interval.negative?
      interval.milliseconds
    end

    private def cache_enabled? : Bool
      memory_cache_limit.positive?
    end

    private def cache_check_due?(entry : CachedFile) : Bool
      interval = cache_check_interval
      return true if interval.zero?

      Time.instant - entry.checked_at >= interval
    end

    private def add_static_cache_headers(headers : HTTP::Headers, file_info : File::Info)
      headers["Etag"] = static_file_etag(file_info)
      headers["Last-Modified"] = HTTP.format_time(file_info.modification_time)
    end

    private def static_file_etag(file_info : File::Info) : String
      %(W/"#{file_info.modification_time.to_unix_ns}-#{file_info.size}")
    end

    private def fresh_cache_entry?(entry : CachedFile, file_info : File::Info) : Bool
      cached_info = entry.file_info
      cached_info.size == file_info.size && cached_info.modification_time == file_info.modification_time
    end

    private def refresh_cached_file(file_path : String, entry : CachedFile) : CachedFile
      refreshed = CachedFile.new(entry.data, entry.file_info, Time.instant)
      @cached_files[file_path] = refreshed
      refreshed
    end

    private def cache_capacity_available?(data_size : Int64, cache_limit : Int64) : Bool
      @cached_bytes + data_size <= cache_limit
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
  end
end
