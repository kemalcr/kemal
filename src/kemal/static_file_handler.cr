module Kemal
  class StaticFileHandler < HTTP::StaticFileHandler
    private def directory_index(context : Server::Context, request_path : Path, path : Path)
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
    private def serve_file(context : Server::Context, file_info, file_path : Path, last_modified : Time)
      send_file(context, file_path.to_s)
    end
  end
end
