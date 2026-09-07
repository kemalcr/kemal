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
          # The index is a static file like any other, so it gets the same negotiation,
          # cache handling and pre-compressed neighbour support.
          serve_file_with_cache(context, index_info, index_path)
        elsif config.fetch("dir_listing", false)
          context.response.content_type = "text/html; charset=utf-8"
          directory_listing(context.response, request_path, file_path)
        else
          call_next(context)
        end
      end

      # Settles which representation of *file_path* answers this request before the cache
      # check runs, so that one decision governs the `Vary` and the entity tag a `304`
      # carries (RFC 9110 §15.4.5) as well as the body a `200` does. It replaces the
      # stdlib's `serve_file_compressed`, whose `Accept-Encoding` matching is by word and so
      # cannot see a `gzip;q=0`.
      private def serve_file_with_cache(context : HTTP::Server::Context, file_info, file_path : Path)
        last_modified = file_info.modification_time
        add_cache_headers(context.response.headers, last_modified)

        variant = precompressed_variant(file_path, last_modified)
        add_negotiation_headers(context, file_path.to_s, file_info.size, variants: !variant.nil?)

        coding = Kemal::Utils.content_coding_for(context.request.headers, file_path.to_s, file_info.size)
        if variant && coding.nil? && accepts_gzip?(context)
          # `send_file` would not compress this file itself — the `gzip` option of
          # `serve_static` is off, or the file is of a type it leaves alone — but a gzip
          # copy of it is already on disk.
          coding = "gzip"
        end

        # The neighbour is gzip already, so it stands in whenever gzip is the coding this
        # request gets. Any other coding `send_file` applies to the stored file itself.
        selected = variant if coding == "gzip"

        if not_modified?(context, last_modified, coding)
          context.response.status = :not_modified
          return
        end

        if selected
          encoded_info, encoded_path = selected
          Kemal::Utils.set_content_coding(context.response.headers, "gzip")
          serve_file(context, encoded_info, encoded_path, file_path, last_modified)
        else
          serve_file(context, file_info, file_path, file_path, last_modified)
        end
      end

      # The pre-compressed `#{file_path}.gz` neighbour that can stand in for *file_path*, or
      # `nil` when there is none. It qualifies only when it is no older than the file it
      # represents; `TIME_DRIFT` allows for the truncated timestamp `gzip --keep` copies on
      # some file systems.
      #
      # Its presence is what makes the URL negotiable, whether or not this request is the
      # one that gets it, so it is looked up before `Accept-Encoding` is read.
      private def precompressed_variant(file_path : Path, last_modified : Time)
        gz_file_path = Path["#{file_path}.gz"]
        gz_file_info = File.info?(gz_file_path)
        return unless gz_file_info && last_modified - gz_file_info.modification_time < TIME_DRIFT

        {gz_file_info, gz_file_path}
      end

      private def accepts_gzip?(context : HTTP::Server::Context) : Bool
        Kemal::Utils.select_content_coding(context.request.headers["Accept-Encoding"]?, {"gzip"}) == "gzip"
      end

      # NOTE: This override routes static files through `send_file` instead of the
      # stdlib's `serve_file`, so that `Kemal.config.max_ranges`, the `gzip` option of
      # `serve_static`, `static_headers` and `X-Content-Type-Options` apply to them.
      # `send_file` serves byte ranges itself, following RFC 9110 like the stdlib does, but
      # ignores a malformed `Range` header where the stdlib answers 400.
      #
      # *file_path* is not always the file the URL names: a pre-compressed `.gz` neighbour
      # stands in for it, with `Content-Encoding` already set. The media type therefore has
      # to come from *original_file_path*, or `app.js` would be served as
      # `application/octet-stream` because `app.js.gz` has no media type of its own.
      # `send_file` leaves a body that already carries a `Content-Encoding` alone.
      private def serve_file(context : HTTP::Server::Context, file_info, file_path : Path, original_file_path : Path, last_modified : Time)
        send_static_file(context, file_path.to_s, MIME.from_filename(original_file_path.to_s, "application/octet-stream"))
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

            index_size = File.size(file_path)
            last_modified = modification_time(file_path)
            add_cache_headers(context.response.headers, last_modified)
            add_negotiation_headers(context, file_path, index_size)

            if not_modified?(context, last_modified, Kemal::Utils.content_coding_for(context.request.headers, file_path, index_size))
              context.response.status_code = 304
              return
            end
            send_static_file(context, file_path)
          elsif config.is_a?(Hash) && config.fetch("dir_listing", false)
            context.response.content_type = "text/html; charset=utf-8"
            directory_listing(context.response, request_path, file_path)
          else
            call_next(context)
          end
        elsif is_file
          file_size = File.size(file_path)
          last_modified = modification_time(file_path)
          add_cache_headers(context.response.headers, last_modified)
          add_negotiation_headers(context, file_path.to_s, file_size)

          if not_modified?(context, last_modified, Kemal::Utils.content_coding_for(context.request.headers, file_path.to_s, file_size))
            context.response.status_code = 304
            return
          end
          send_static_file(context, file_path.to_s)
        else # Not a normal file (FIFO/device/socket)
          call_next(context)
        end
      end

      private def modification_time(file_path)
        File.info(file_path).modification_time
      end
    {% end %}

    # Serves the file through `send_file`. A file that exists but cannot be opened -
    # permissions, a race with its removal - is reported as not found, as the stdlib
    # does: a `500` would put the absolute path on the development error page and
    # confirm to the client that the file is there. `respond_with_status` drops the
    # cache and negotiation headers already derived from the file for the same reason.
    private def send_static_file(context : HTTP::Server::Context, path : String, mime_type : String? = nil) : Nil
      send_file(context, path, mime_type)
    rescue File::Error
      context.response.respond_with_status(:not_found)
    end

    # Says that the response body depends on `Accept-Encoding` whenever this URL has more
    # than one representation to offer — a pre-compressed neighbour, or a file `send_file`
    # compresses on the fly — whether or not this particular response is the encoded one
    # (RFC 9110 §12.5.5). It runs before the cache check so that a `304` says it too.
    private def add_negotiation_headers(context : HTTP::Server::Context, path : String, size : Int, variants : Bool = false) : Nil
      return unless variants || Kemal::Utils.compressible?(path, size)

      Kemal::Utils.append_vary(context.response.headers, "Accept-Encoding")
    end

    # Whether the client's copy is still current, and the answer is a `304`.
    #
    # `HTTP::StaticFileHandler#cache_request?` compares `If-None-Match` against the entity
    # tag of the stored file, but a body encoded with *coding* is given a tag of its own
    # (see `Kemal::Utils.etag_with_coding`), so the comparison is against the tag a `200`
    # for this request would carry — the selected representation's, and only that one
    # (RFC 9110 §13.1.2). Accepting the stored file's tag as well would confirm a copy the
    # client holds of a representation it is not being sent, which is the confusion the
    # distinct tags exist to prevent.
    private def not_modified?(context : HTTP::Server::Context, last_modified : Time, coding : String? = nil) : Bool
      if_none_match = context.request.if_none_match
      return cache_request?(context, last_modified) unless if_none_match

      etag = context.response.headers["Etag"]?
      return if_none_match.includes?("*") unless etag

      selected = coding ? Kemal::Utils.etag_with_coding(etag, coding) : etag
      return false unless if_none_match.includes?("*") || if_none_match.includes?(selected)

      # A `304` names the validator of the representation it stands for.
      context.response.headers["Etag"] = selected
      true
    end
  end
end
