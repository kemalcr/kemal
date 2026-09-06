module Kemal
  module Utils
    ZIP_TYPES = {".htm", ".html", ".txt", ".css", ".js", ".svg", ".json", ".xml", ".otf", ".ttf", ".woff", ".woff2"}

    # The content codings Kemal can apply to a response body, most preferred first. The
    # order breaks ties between codings the client is equally happy with. `send_file` has a
    # writer for each of them; adding one here without adding its writer there leaves the
    # body unencoded.
    CONTENT_CODINGS = {"gzip", "deflate"}

    # Below this size the framing a content coding adds costs more than the coding saves.
    # https://webmasters.stackexchange.com/questions/31750/what-is-recommended-minimum-object-size-for-gzip-performance-benefits
    COMPRESS_MIN_SIZE = 860

    def self.path_starts_with_slash?(path : String)
      path.starts_with? '/'
    end

    def self.zip_types(path : String) # https://github.com/h5bp/server-configs-nginx/blob/master/nginx.conf
      ZIP_TYPES.includes? File.extname(path)
    end

    # Whether `send_file` compresses a file of *size* bytes stored at *path*, given the
    # `gzip` option of `serve_static`. This also decides whether the response needs a
    # `Vary: Accept-Encoding`, which is why `Kemal::StaticFileHandler` asks before it knows
    # whether it is answering with a body at all.
    def self.compressible?(path : String, size : Int) : Bool
      # Built without a compressor, Kemal has only the stored bytes to offer, so nothing
      # about the response depends on `Accept-Encoding`.
      {% if flag?(:without_zlib) %}
        return false
      {% end %}

      config = Kemal.config.serve_static

      config.is_a?(Hash) && config["gzip"]? == true && size > COMPRESS_MIN_SIZE && zip_types(path)
    end

    # Exact prefix, or prefix followed by `/`. `"/"`, and `""` match all paths.
    def self.matches_path_prefix?(prefix : String, path : String) : Bool
      return true if prefix.in?("/", "")

      return true if path == prefix

      path.starts_with?("#{prefix}/")
    end

    # Parses an `Accept-Encoding` field value into its content codings and their qvalues
    # ([RFC 9110 §12.5.3](https://www.rfc-editor.org/rfc/rfc9110#section-12.5.3)). Coding
    # names are case-insensitive (§8.4.1) and come back lowercased, with `x-gzip` folded
    # into `gzip` (§8.4.1.3); `*` is kept as is.
    #
    # An element whose qvalue is not a number in `0..1` is dropped rather than taken as
    # `q=1`, so a garbled field value cannot be read as a request for compression, and a
    # coding listed more than once keeps its lowest qvalue, so a later duplicate cannot
    # undo a refusal.
    #
    # ```
    # Kemal::Utils.parse_accept_encoding("gzip;q=0.5, deflate") # => {"gzip" => 0.5, "deflate" => 1.0}
    # ```
    def self.parse_accept_encoding(value : String) : Hash(String, Float64)
      codings = {} of String => Float64

      value.split(',') do |element|
        coding, _, parameters = element.partition(';')
        coding = coding.strip
        next if coding.empty?

        q = qvalue(parameters) || next
        coding = coding.downcase
        # RFC 9110 §8.4.1.3: a recipient is to treat `x-gzip` as `gzip`. §12.5.3 notes that
        # qvalues are not permitted with the alias, but honoring one can only refuse a
        # coding, never ask for one, so it is read the same way as any other element.
        coding = "gzip" if coding == "x-gzip"
        previous = codings[coding]?
        codings[coding] = previous ? {previous, q}.min : q
      end

      codings
    end

    # Reads the `q` parameter out of the parameters of one `Accept-Encoding` element.
    # Returns `1.0` when the element carries no `q`, and `nil` when it carries one that is
    # not a qvalue.
    private def self.qvalue(parameters : String) : Float64?
      return 1.0 if parameters.empty?

      parameters.split(';') do |parameter|
        name, equals, value = parameter.partition('=')
        next if equals.empty?
        next unless name.strip.compare("q", case_insensitive: true) == 0

        q = value.strip.to_f?
        return unless q && 0.0 <= q <= 1.0
        return q
      end

      1.0
    end

    # Picks the content coding to apply to a response, given the request's
    # *accept_encoding* field value and the *available* codings the caller can produce
    # ([RFC 9110 §12.5.3](https://www.rfc-editor.org/rfc/rfc9110#section-12.5.3)).
    #
    # Returns `"identity"` when the body should be sent unencoded, and `nil` when the field
    # value rules out every coding, `identity` included. RFC 9110 has the origin server
    # send an unencoded response in that case as well, so `nil` may be treated as
    # `"identity"`; it is distinct only so that a caller can tell the two apart.
    #
    # A missing field is answered with `"identity"`: it carries no preference, and Kemal
    # does not compress a response the client did not ask to have compressed.
    #
    # ```
    # Kemal::Utils.select_content_coding("gzip;q=0, deflate") # => "deflate"
    # Kemal::Utils.select_content_coding("gzip;q=0")          # => "identity"
    # Kemal::Utils.select_content_coding("identity;q=0")      # => nil
    # ```
    def self.select_content_coding(accept_encoding : String?, available : Enumerable(String) = CONTENT_CODINGS) : String?
      return "identity" unless accept_encoding

      codings = parse_accept_encoding(accept_encoding)
      wildcard = codings["*"]?

      best = nil
      best_q = 0.0
      available.each do |coding|
        q = codings[coding]? || wildcard || 0.0
        next unless q > best_q
        best = coding
        best_q = q
      end

      identity = codings["identity"]? || wildcard

      if best.nil?
        # `identity` is acceptable by default; only an explicit `identity;q=0`, or a `*;q=0`
        # with no entry of its own for `identity`, refuses the unencoded body as well.
        identity.nil? || identity > 0.0 ? "identity" : nil
      elsif identity.nil? || best_q >= identity
        # A client that listed a coding at all asked for it in preference to the stored
        # bytes, so an unstated `identity` loses to it. Once the field value does state a
        # qvalue for `identity`, directly or through `*`, it is ranked like any other coding.
        best
      else
        "identity"
      end
    end

    # Adds *field* to the `Vary` response header, keeping the fields already listed there.
    # A field that is present, and the `*` that already covers every field, are left alone.
    def self.append_vary(headers : HTTP::Headers, field : String) : Nil
      existing = headers["Vary"]?
      if existing.nil? || existing.empty?
        headers["Vary"] = field
        return
      end

      existing.split(',') do |name|
        name = name.strip
        return if name == "*" || name.compare(field, case_insensitive: true) == 0
      end

      headers["Vary"] = "#{existing}, #{field}"
    end

    # Marks *etag* as identifying the *coding* encoded form of a representation, so that the
    # encoded and identity forms of one file cannot share a validator
    # ([RFC 9110 §8.8.1](https://www.rfc-editor.org/rfc/rfc9110#section-8.8.1)). The suffix
    # is spelled the way nginx and Apache spell it.
    #
    # Only the codings in `CONTENT_CODINGS` are marked. A tag Kemal cannot reproduce from
    # the file's own tag is one it could never match on revalidation, which would re-send
    # the whole body every time, so a coding the application applied itself is left alone.
    #
    # ```
    # Kemal::Utils.etag_with_coding(%(W/"1700000000"), "gzip") # => %(W/"1700000000-gzip")
    # ```
    def self.etag_with_coding(etag : String, coding : String) : String
      return etag unless CONTENT_CODINGS.includes?(coding) && etag.ends_with?('"')

      %(#{etag.rchop}-#{coding}")
    end

    # The content coding `send_file` applies to a file of *size* bytes at *path* for a
    # request carrying *request_headers*, or `nil` when it sends the stored bytes as they
    # are. `Kemal::StaticFileHandler` has to know the answer before it writes a body, to
    # name the right entity tag on a `304`, so both ask the same question here rather than
    # each working it out for itself.
    def self.content_coding_for(request_headers : HTTP::Headers, path : String, size : Int) : String?
      return unless compressible?(path, size)

      coding = select_content_coding(request_headers["Accept-Encoding"]?)
      coding unless coding == "identity"
    end

    # Records *coding* as the content coding of a response and gives the encoded form its
    # own entity tag, so that a cache holding the identity representation under `W/"..."`
    # cannot hand it to a client being served the encoded one (RFC 9110 §8.8.1). The
    # `-gzip` style suffix is the one nginx and Apache use.
    #
    # Only for a coding Kemal applied itself: an entity tag that came with a body the
    # caller encoded already describes that body.
    def self.set_content_coding(headers : HTTP::Headers, coding : String) : Nil
      headers["Content-Encoding"] = coding

      if etag = headers["Etag"]?
        headers["Etag"] = etag_with_coding(etag, coding)
      end
    end
  end
end
