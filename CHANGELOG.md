# Unreleased

- ***(BREAKING)*** Answer a request whose path is routed for another HTTP method with `405 Method Not Allowed` and the `Allow` header instead of `404`, per [RFC 9110 §15.5.6](https://www.rfc-editor.org/rfc/rfc9110#section-15.5.6). With only `get "/posts"` registered, `POST /posts` and `OPTIONS /posts` returned `404` and reached the `error 404` handler; they now return `405` with `Allow: GET, HEAD` and reach `error 405`. Anything asserting `404` for a wrong-method request — tests, client retry logic, monitoring rules — has to be updated. A path that is not routed at all is still a `404`; `ws` routes are covered by the entry below. `HEAD` appears in `Allow` wherever a `GET` route exists, matching the `HEAD` -> `GET` fallback. The `Allow` header is set before the error handler runs, so a custom `error 405` owns the body but cannot drop the header the RFC makes mandatory; without one, the body is the plain `Method Not Allowed`. Registering `error 405` also makes `before_all` filters run for *every* unmatched request, plain 404s included - the same over-approximation the existing `error 404` branch already had, now reachable through a second status code. Automatic `OPTIONS` responses are not part of this change.

```crystal
get "/posts" do
  "posts"
end

# POST /posts -> 405, Allow: GET, HEAD
# GET /nope   -> 404

error 405 do |env|
  # `Kemal::InitHandler` presets `Content-Type: text/html` for every response
  env.response.content_type = "application/json"
  {error: "Method not allowed", allow: env.response.headers["Allow"]}.to_json
end
```

- `Kemal::Config#clear` now also resets `serve_static`, `public_folder`, `static_headers`, `shutdown_message` and `shutdown_timeout`, so a spec that sets one of them no longer leaks it into the next. CI gains three variant runs on the current compiler — `--release`, `-Dwithout_zlib` and `-Dwithout_openssl`, the two flags with code paths of their own in `src/` — and a run with the default execution context widened to four workers (Crystal 1.21; set `KEMAL_SPEC_WORKERS` to do the same locally), so the request path is exercised from several threads. Specs that need zlib are skipped under `-Dwithout_zlib`, and every spec file now compiles on its own.
- Count the discarded body of a `HEAD` request in an `Int64` [#803](https://github.com/kemalcr/kemal/issues/803). `Kemal::HeadRequestHandler` swallows the body a `HEAD` request generates and counts the bytes to set `Content-Length`, and the counter was an `Int32`; Crystal checks integer overflow, so the 2 147 483 648th byte raised `OverflowError`, which `Kemal::ExceptionHandler` — further down the chain — turned into a `500`. `HEAD` on a file of 2 GiB or more therefore answered `500` where the matching `GET` answered `200`, with the threshold at exactly `Int32::MAX`. A route generating a body over that size also reported the partial count as its `Content-Length`, since `NullIO` sets the header from the counter when the handler has not set one itself. `HTTP::Server::Response#content_length` already returns `Int64?`, so the counter was the only `Int32` left in the path.
- Spool an upload through the handle `File.tempfile` already opened, instead of opening the path a second time to write [#801](https://github.com/kemalcr/kemal/issues/801). One descriptor and one `open` per upload rather than two, and the file is no longer reopened by name right after being created by descriptor. `FileUpload#tempfile` still comes back open for reading and positioned at the start. `FileUpload#size` is now the number of bytes written to disk; it used to be the `size` the part's `Content-Disposition` claimed, which the client chooses.
- Finish the requests in flight before exiting on a termination signal [#795](https://github.com/kemalcr/kemal/issues/795). `Kemal.stop` closed the listeners and then slept for `shutdown_timeout`, but `HTTP::Server#listen` returns as soon as the listeners close, so `Kemal.run` returned, the program ended and the process exited a few milliseconds after `SIGTERM` — before the sleep ran, cutting off whatever was being served, and for any value of `shutdown_timeout`. `Kemal.run` now returns only once every request that was in flight when the server stopped has finished, or `shutdown_timeout` has elapsed, whichever comes first; with nothing in flight it returns at once. `shutdown_timeout` therefore changes from a fixed sleep into an upper bound, and its default from `0` to `30.seconds`, since `0` would keep cutting requests off. `Kemal.stop` itself no longer blocks. The signal handler no longer calls `exit`: `Kemal.run` returns after the drain and the program carries on to its end, so code after `Kemal.run` now runs on `SIGTERM` as it already did on `Kemal.stop`. A second signal during the drain exits immediately. A WebSocket or SSE connection counts as in flight for as long as it stays open; an application holding such connections waits the full `shutdown_timeout` unless it closes them itself. The count is exposed as `Kemal::InitHandler::INSTANCE.in_flight`, and `Kemal.config.running` is set to `false` before the listeners close so a health route can report the drain.
- Count a `ws` route as `GET` when collecting the `Allow` header, since the WebSocket handshake is a `GET` request ([RFC 6455 §4.1](https://www.rfc-editor.org/rfc/rfc6455#section-4.1)). Two fixes:

  - A path served only by `ws` now answers wrong-method requests with `405` and `Allow: GET`. Previously `Kemal::WebSocketHandler` passed a non-handshake request straight through and the route lookup missed, so `POST /chat` ended as a `404` — or, with no `error 404` handler registered, an empty `200`.
  - A path carrying both `ws` and HTTP routes no longer reports an `Allow` that omits the handshake: with `ws "/chat"` and `post "/chat"`, `PUT /chat` answers `Allow: GET, POST` rather than `Allow: POST`.

  - `Kemal::WebSocketHandler` no longer hardcodes `Allow: GET` when it rejects a non-GET upgrade attempt. `Allow` describes the methods the *resource* supports ([RFC 9110 §10.2.1](https://www.rfc-editor.org/rfc/rfc9110#section-10.2.1)), so with `ws "/chat"` and `post "/chat"` a `POST` carrying `Upgrade: websocket` now answers `Allow: GET, POST` instead of sending the client away from a verb the path really serves. A path with only a `ws` route still answers `Allow: GET`.

  `HEAD` is not advertised for a `ws` route — the handshake is the only thing served there. And a request whose own method is already in the `Allow` list is not a `405`: a plain `GET` on a `ws` path is a handshake missing its `Upgrade` header, so it stays a `404` instead of being told `405, Allow: GET`. `426 Upgrade Required` ([RFC 9110 §15.5.22](https://www.rfc-editor.org/rfc/rfc9110#section-15.5.22)) was considered for that case and deliberately not adopted: a plain `GET` there is a client bug, and `404` versus `426` does not change what the client has to do.

```crystal
ws "/chat" do |socket, env|
  socket.send("hi")
end

post "/chat" do
  "post"
end

# PUT  /chat -> 405, Allow: GET, POST
# GET  /chat -> 404 (no `Upgrade` header, so not a handshake)
```




- Report a static file that exists but cannot be opened as `404`, as the standard library's `HTTP::StaticFileHandler` does. Kemal's override served files through `send_file` without the stdlib's `File::Error` rescue, so a file under `public/` without read permission answered `500` — with the absolute path on the development error page, and the file's `ETag` and `Last-Modified` on the response, confirming to the client that the file was there. The response is now the plain `404` the stdlib sends, with no header derived from the file.
- ***(SECURITY)*** Cap the number of file parts in a `multipart/form-data` request [#793](https://github.com/kemalcr/kemal/issues/793). `max_request_body_size` bounds the bytes but said nothing about the parts, and every file part is spooled to its own temporary file whose handle stays open until the request is over: an 8 MB body of one-byte parts held some 100,000 open file descriptors and temporary files for the length of one request, enough to take a process with the default `ulimit -n 1024` past `accept()` from a single unauthenticated request. `Kemal.config.max_file_uploads` (default `128`) now bounds the file parts; a request carrying more is answered with `413` and the body `Too many file parts (max N)` before the next part is written to disk, and the parts already spooled are cleaned up with the request. Form fields without a filename are not counted. `Kemal::Exceptions::PayloadTooLarge.new` now takes an optional message for this. Two related leaks are closed as well: a file part whose field name repeats an earlier one used to replace that upload in `params.files` without removing its temporary file, leaving it on disk for good; and `params.all_files` did not parse the body on its own, so it was always empty unless `params.files` had been read first.
- Answer `HEAD` on an `sse` route with the stream's headers instead of running the handler. `HEAD` is served from the `GET` route with the body discarded, and an SSE handler is typically an endless loop that only stops when a write fails because the client has gone. On `HEAD` nothing it wrote went anywhere, so the loop never saw the client leave: every `HEAD` to an SSE endpoint pinned a fiber for the life of the process, and a client that sent a few hundred of them exhausted it without authenticating. `Kemal::EventStream.serve` now sets the headers and returns without yielding when the request method is `HEAD`.
- ***(SECURITY)*** Stop reflecting the request into `Kemal::Exceptions::RouteNotFound#message`. It read `Requested path: 'GET:/…' was not found.` with the method and path verbatim, and an `error 404` handler that returns `ex.message` — the obvious thing to write — sent that back as `text/html`, so `GET /<script>…</script>` was a reflected XSS. The message is now the bare `Not Found`, as `MethodNotAllowed`'s already was; the request stays reachable through the new `RouteNotFound#context`. The `error` docs now show `HTML.escape` around a message built from request data.
- Fix `content_for` blocks leaking between concurrent requests [#789](https://github.com/kemalcr/kemal/issues/789). Captured blocks were kept in a process-global `CONTENT_FOR_BLOCKS` hash, so two requests rendering the same view at once overwrote each other: whichever fiber reached the layout second ran the other request's block, which wrote into the other request's buffer. One page lost its `yield_content` output and could pick up the other's instead, with no error raised. Any fiber switch between the view and the layout — a database call in a view, or `-Dpreview_mt` — triggered it. Blocks are now held in a local that `render(view, layout)` declares, so each render sees only what it captured itself. `CONTENT_FOR_BLOCKS` is gone, and `content_for`/`yield_content` are only usable inside a `render(view, layout)` call (directly in the view, or in a partial it renders); the `file` argument `content_for` took to tell views apart is no longer needed and has been removed.
- ***(SECURITY)*** Serve the development error page only in the `development` environment [#791](https://github.com/kemalcr/kemal/issues/791). The choice between the development page — exception message, backtrace with source, response headers, cookies — and the static production page was `env == "production"`, so every other value of `KEMAL_ENV` got the development page: `staging`, `test`, and typos such as `prod` or `Production` all disclosed the failure to the client. The check is now `env == "development"`; an environment Kemal does not recognize gets the production page. `Kemal.config.show_exceptions = true` shows the development page in another environment, `false` never shows it, and unset (the default) follows the environment. A registered `error 500` handler is unaffected; the setting only chooses between the two built-in pages. Apps that relied on the development page in an environment other than `development` need to set `show_exceptions`.

- Fix `Range` handling in `send_file` per [RFC 9110 §14](https://www.rfc-editor.org/rfc/rfc9110#section-14) and [§15.5.17](https://www.rfc-editor.org/rfc/rfc9110#section-15.5.17). The parser could not tell an omitted last-pos from `0`, required the last-pos to be strictly greater than the first-pos, and dropped ranges that reached the end of the file: `bytes=0-0` served the whole file as a `206`, `bytes=5-5` and `bytes=17-` fell back to a `200`, and `bytes=0-4,7-7` silently lost its second part. A last-pos beyond the end is now clamped (`bytes=0-99999` → `0-17/18`), suffix ranges are supported (`bytes=-5` → `13-17/18`), a valid range set none of whose ranges is satisfiable is answered with `416` and `Content-Range: bytes */<length>` instead of `200`, and a byte position that overflows `Int64` counts as beyond the end of the file instead of `0`. Each part of a `multipart/byteranges` response now carries the media type of the file rather than `multipart/byteranges; boundary=...`. A malformed `Range` header, a unit other than `bytes`, `Range` on `HEAD`, and range sets refused as abusive (see `Kemal.config.max_ranges`) are still served as a plain `200`.

- Fix content coding negotiation in `send_file` and static file serving, per [RFC 9110 §8.4](https://www.rfc-editor.org/rfc/rfc9110#section-8.4), [§12.5.3](https://www.rfc-editor.org/rfc/rfc9110#section-12.5.3) and [§12.5.5](https://www.rfc-editor.org/rfc/rfc9110#section-12.5.5):

  - `Content-Encoding: deflate` now carries the zlib format of RFC 1950, which is the `deflate` coding [RFC 9110 §8.4.1.2](https://www.rfc-editor.org/rfc/rfc9110#section-8.4.1.2) defines. Kemal sent a bare RFC 1951 stream; browsers sniff that, stricter clients do not.
  - `Accept-Encoding` qvalues are honored, so `gzip;q=0` no longer gets a gzip body. The highest ranked coding wins, and `*` and `identity;q=0` are understood. The parser is `Kemal::Utils.select_content_coding`.
  - A response whose representation `Accept-Encoding` selects now carries `Vary: Accept-Encoding`, whether or not this particular response was compressed, added to any `Vary` the application already set. Without it a shared cache serves one client the variant it stored for another.
  - A pre-compressed `app.js.gz` (Crystal 1.17+) is served with the media type of `app.js` instead of `application/octet-stream`, is not compressed a second time, and is chosen with the same qvalue rules rather than the standard library's word match. A multi-range request for it falls back to the whole body, since the `multipart/byteranges` envelope carrying the parts is not itself encoded.
  - The encoded variant gets an entity tag of its own (`W/"1700000000-gzip"`), so a cache cannot mistake it for the identity representation, and `If-None-Match` is matched against the tag the request would actually be answered with.

  Range responses stay uncompressed, as before. `gzip true` installs the standard library's `HTTP::CompressHandler`, which has none of these fixes; prefer `serve_static({"gzip" => true})` for static assets.

- Omit the SSE `retry` field for negative `Time::Span` values instead of emitting e.g. `retry: -3000`, which clients discard per the SSE spec. The value now renders via `.to_u64`; output for non-negative spans is unchanged.

- Skip filter tree lookups when no path-scoped filters are registered. Apps using only global filters (`before_all` and friends) no longer pay 4-6 radix lookups and key allocations per request [#781](https://github.com/kemalcr/kemal/pull/781).

- Cache the `Date` response header string per second instead of formatting it on every request. The value is unchanged: the string is reused only within the same UTC second [#781](https://github.com/kemalcr/kemal/pull/781).

# 1.13.0 (24-08-2026)

- ***(SECURITY)*** Delete uploaded temporary files for every request, not only for requests that reach `Kemal::RouteHandler` [#776](https://github.com/kemalcr/kemal/issues/776). `Kemal::ParamParser` spools multipart file parts to `File.tempfile` as soon as anything touches `params` — including `params.body` on a multipart request, which writes every file part out just to read one form field — but cleanup ran in the route handler's `ensure`. Anything that answered before the route handler leaked those files permanently: a `before` filter that `halt`s into a custom `error` handler (Kemal's documented auth pattern), an exception raised in a filter, and middleware that responds without calling the next handler. An unauthenticated client could therefore fill the disk one *rejected* upload at a time — with default settings, 20 curl requests left 153 MB behind for good. Cleanup now lives in `Kemal::InitHandler`, which heads the handler chain, so it runs however the request ends. A handler registered ahead of it with `use handler, 0` still owns the cleanup for uploads it parses itself, as that position already opts out of everything else `Kemal::InitHandler` does. Thanks @canermastan for the report :pray:

- Add HTTP QUERY method support ([RFC 10008](https://www.rfc-editor.org/rfc/rfc10008)) [#762](https://github.com/kemalcr/kemal/issues/762): `query` route DSL, `Kemal::Router#query`, and `before_query` / `after_query` filters. A QUERY request that has a body but no `Content-Type` header is rejected with `400` per the RFC; media-type decisions (415/406/422) and the `Accept-Query` response header remain in the application's hands. Thanks @canermastan for the request :pray:

```crystal
query "/search" do |env|
  q = env.params.json["q"]? # or env.params.body for form-encoded queries
  search_products(q).to_json
end
```

- ***(SECURITY)*** Run the `GET` filters for `HEAD` requests served by the `GET` route ([GHSA-jf9q-62h3-924j](https://github.com/kemalcr/kemal/security/advisories/GHSA-jf9q-62h3-924j)). Kemal serves a `HEAD` request with the `GET` route when no explicit `HEAD` route exists, but `Kemal::FilterHandler` dispatched verb specific filters on the literal request method. `before_get` and `after_get` were therefore skipped while the `GET` handler still ran, so `HEAD /admin/users` bypassed a `before_get` authentication filter — Kemal's documented auth pattern — executed the protected handler along with its side effects, returned the headers that handler set, and left no `after_get` audit record. Filters now run for both the request method and the method of the route that serves it, so the `GET` filters guard `HEAD` while filters registered for `HEAD` keep firing. A route registered explicitly for `HEAD` is unaffected. Thanks @JirayuThongchotchaung for the report :pray:

- ***(SECURITY)*** Scope `Kemal::Handler` `only` / `exclude` by the route that serves the request as well as by the request method, so `HEAD` cannot slip past middleware scoped to `GET`. This is the same defect as the filter fix above, in the sibling API: `only ["/admin/*"]` — the `GET` default — did not match `HEAD /admin/users`, so authentication middleware never ran while the `GET` handler executed and returned the headers it set. Rules scoped to `HEAD` keep matching, and verbs that carry their own handler are untouched: a `POST` rule still ignores `HEAD`. `exclude` follows the same rule, so a `HEAD` request served by an excluded `GET` route is now excluded too — matching what that route already does for `GET`.

- ***(SECURITY)*** Register `Kemal::Router` filters whose path ends in `/*`. `register_filters` treated the trailing `*` as a literal path segment, so `router.before_get "/*"` and `router.before_get "/admin/*"` matched no route and were silently registered nowhere — a router-scoped filter used for authentication never ran, for any HTTP method. A trailing `/*` now marks a subtree, so `"/admin/*"` scopes the filter to the same routes as `"/admin"`, and `"/*"` covers every route in the router just like `"*"`. Filter paths without a glob are unchanged.

- Register a `Kemal::Router` filter once per path instead of once per route on that path. A path carrying several methods — `router.get "/users"` plus `router.post "/users"` — got the same filter block appended once per method, so the filter ran that many times for a single request, double-counting rate limits and duplicating audit records.

- Drop the cached `HEAD` → `GET` fallback for a path when a `HEAD` route is registered for it afterwards. The stale cache entry kept routing `HEAD` to the `GET` handler, and it now also selects which verb scoped filters and `only` / `exclude` rules apply.

- ***(SECURITY)*** Bound the byte ranges `send_file` serves for a single `Range` request header. Ranges were served unchecked, and since an open-ended `bytes=0-` expands to the whole file, a header such as `bytes=0-,0-,0-,...` turned one 16 KB request into a response thousands of times the file's size (the CVE-2011-3192 "Apache Killer" pattern). Affects any app serving static files, which is the default. A range set is now ignored — and the full representation served instead, as RFC 9110 §14.2 allows — when it lists more than `Kemal.config.max_ranges` parts (16 by default) or asks for more bytes in total than the file holds. Requests within those limits are unchanged. Ignored and unsatisfiable `Range` headers now take the same path as a plain `GET`, so they are compressed as usual. Thanks @onurcangnc for the report :pray:

```crystal
# Allow more parts per Range request, or set to 0 to ignore Range headers entirely
Kemal.config.max_ranges = 16
```

- ***(SECURITY)*** Escape the request path and the exception message on the development error page. Both reached the `exception_page` template unescaped, so a crafted URL — or user input interpolated into an exception message, e.g. `raise "User #{name} not found"` — could run JavaScript in the visitor's browser (reflected XSS). The page is now also served with a restrictive `Content-Security-Policy`. Only affects `Kemal.config.env == "development"`, which is the default; the production error page never reflected request data. Thanks @onurcangnc for the report :pray:

- ***(SECURITY)*** WebSocket Origin validation is same-origin by default (CSWSH). An empty `websocket_allowed_origins` now requires `Origin` to match the request `Host` (scheme taken from `Origin`, so reverse-proxy TLS termination keeps working). Missing or empty `Origin` is rejected with 403. Set `Kemal.config.websocket_allowed_origins = ["*"]` to opt into allowing any origin, including requests without `Origin`. Explicit allowlists behave as before.

```crystal
# Default: same-origin (secure)
# Kemal.config.websocket_allowed_origins = [] of String

# Explicit allowlist
Kemal.config.websocket_allowed_origins = ["https://myapp.com", "http://localhost:3000"]

# Previous allow-all behavior (opt-in)
Kemal.config.websocket_allowed_origins = ["*"]
```

- ***(SECURITY)*** Prevent SSE injection in `Kemal::EventStream`: reject newlines in `event`/`id`, normalize CR/LF in `data`/`comment`. Thanks @hahwul for the report. Thanks @sdogruyol for the fix :pray:
- Fix URL params being decoded again on every request when route lookup results are cached. Thanks @hahwul for the report. Thanks @sdogruyol for the fix :pray:

- Add `only` / `exclude` opt-in matching for all HTTP methods (`"*"`) and path prefixes (`"/*"`). Defaults remain GET + exact path. Clarified docs and the basic-auth custom handler example. Thanks @hahwul for the report. Thanks @sdogruyol :pray:

- Fix `only` / `exclude` with method `"*"` over-matching every path: Radix treats `*` as a glob, so the all-methods marker is stored under a safe sentinel. Thanks @hahwul for the report. Thanks @sdogruyol :pray:

- ***(SECURITY)*** Close the HTTP connection after a rejected WebSocket upgrade (403). Without `Connection: close`, a compound `Connection: keep-alive, Upgrade` request that fails Origin validation left the connection keep-alive, so a request pipelined behind a reverse proxy that tunnels upgrades could bypass the proxy’s access controls (WebSocket connection smuggling). Malformed `Origin` values that previously raised from `URI.parse` now reject with 403 instead of 500.

- WebSocket upgrades now require the `GET` method per [RFC 6455 §4.1](https://www.rfc-editor.org/rfc/rfc6455.html#section-4.1) [#770](https://github.com/kemalcr/kemal/issues/770). Any other method (`POST`, `QUERY`, ...) carrying valid upgrade headers previously completed the handshake; it is now rejected with `405 Method Not Allowed`, an `Allow: GET` header, and `Connection: close` — matching the broader ecosystem (gorilla/websocket, Node `ws`, python-websockets).

- Respond 400 instead of 500 for malformed request bodies (invalid JSON, unparseable multipart) [#772](https://github.com/kemalcr/kemal/pull/772). Thanks @sdogruyol :pray:

- Fix `Int32` overflow in the SSE `retry` field for spans beyond ~24.8 days [#771](https://github.com/kemalcr/kemal/pull/771). Thanks @sdogruyol :pray:

- Disable the `X-Powered-By` header by default. Set `Kemal.config.powered_by_header = true` to restore the previous behavior.

- Add Crystal-Kemal agent skills for routing, WebSockets, SSE, JSON APIs, middleware, uploads, auth, and related domains [#774](https://github.com/kemalcr/kemal/pull/774) [#777](https://github.com/kemalcr/kemal/pull/777).

# 1.12.0 (21-07-2026)

- Crystal 1.21.0 support :tada:
- Add `sse` helper for Server-Sent Events [#755](https://github.com/kemalcr/kemal/pull/755). Thanks @sdogruyol :pray:

```crystal
sse "/events" do |stream, env|
  stream.send("tick", event: "tick", id: 1)
end
```

- Fix unhandled exception when headers were already sent to the client [#760](https://github.com/kemalcr/kemal/pull/760). Thanks @sdogruyol :pray:
- Fix `before_all` filters running twice [#758](https://github.com/kemalcr/kemal/pull/758). Thanks @sdogruyol :pray:
- Show actual defaults in `--help` when host/port are overridden [#751](https://github.com/kemalcr/kemal/pull/751). Thanks @Singond :pray:
- Simplify helpers with version controls [#752](https://github.com/kemalcr/kemal/pull/752). Thanks @sdogruyol :pray:
- Raise minimum Crystal version to `>= 1.12.0`
- Fix MySQL example placeholder syntax [#756](https://github.com/kemalcr/kemal/pull/756). Thanks @drum445 :pray:

# 1.11.0 (13-04-2026)

- ***(SECURITY)*** Fix chunked multipart body limits [#748](https://github.com/kemalcr/kemal/pull/748). Thanks @canermastan :pray:

This PR adds a new config option:

```crystal
Kemal.config.max_multipart_form_field_size = 8 * 1024 * 1024
```

- ***(SECURITY)*** Add Websocket origin validation and configuration support [#749](https://github.com/kemalcr/kemal/pull/749). Thanks @past3l :pray:

This PR adds a new config option:

```crystal
Kemal.config.websocket_allowed_origins = ["https://myapp.com", "http://localhost:3000"]
```

# 1.10.1 (24-03-2026)

- Add `shutdown_timeout` configuration for graceful shutdown: after `Kemal.stop`, Kemal can wait before exit so in-flight work can finish [#745](https://github.com/kemalcr/kemal/pull/745). Thanks @sdogruyol :pray:

```crystal
Kemal.config.shutdown_timeout = 10.seconds
```

# 1.10.0 (03-03-2026)

- Add modular `Kemal::Router` with namespaced routing, scoped filters, WebSocket support and flexible mounting while keeping the existing DSL fully compatible [#731](https://github.com/kemalcr/kemal/pull/731). Thanks @sdogruyol :pray:

```crystal
require "kemal"

api = Kemal::Router.new

api.namespace "/users" do
  get "/" do |env|
    env.json({users: ["alice", "bob"]})
  end

  get "/:id" do |env|
    env.text "user #{env.params.url["id"]}"
  end
end

mount "/api/v1", api

Kemal.run
```

- Add `use` keyword for registering global and path-specific middleware, including support for arrays and insertion at a specific position in the handler chain [#734](https://github.com/kemalcr/kemal/pull/734). Thanks @sdogruyol :pray:

```crystal
require "kemal"

# Path-specific middlewares for /api routes
use "/api", [CORSHandler.new, AuthHandler.new]

get "/" do
  "Public home"
end

get "/api/users" do |env|
  env.json({users: ["alice", "bob"]})
end

Kemal.run
```

- Enhance response helpers to provide chainable JSON/HTML/text/XML helpers, `HTTP::Status` support and the ability to halt execution from a chained response for concise API error handling [#733](https://github.com/kemalcr/kemal/pull/733), [#735](https://github.com/kemalcr/kemal/pull/735), [#736](https://github.com/kemalcr/kemal/pull/736). Thanks @sdogruyol and @mamantoha :pray:

```crystal
require "kemal"

get "/users" do |env|
  # Default JSON response
  env.json({users: ["alice", "bob"]})
end

post "/users" do |env|
  # Symbol-based HTTP::Status and chained JSON
  env.status(:created).json({id: 1, created: true})
end

get "/admin" do |env|
  # Halt immediately with HTML response
  halt env.status(403).html("<h1>Forbidden</h1>")
end

get "/api/users" do |env|
  # Custom content type (JSON:API)
  env.json({data: ["alice", "bob"]}, content_type: "application/vnd.api+json")
end

Kemal.run
```

- Ensure global wildcard filters always execute while keeping namespace filters isolated to their routes [#737](https://github.com/kemalcr/kemal/pull/737). Thanks @mamantoha :pray:
- Fix CLI SSL validation and expand CLI option parsing specs [#738](https://github.com/kemalcr/kemal/pull/738). Thanks @sdogruyol :pray:
- Make route LRU cache concurrency-safe with Mutex [#739](https://github.com/kemalcr/kemal/pull/739). Thanks @sdogruyol :pray:
- Add `raw_body` to ParamParser for multi-handler body access (e.g. kemal-session) [#740](https://github.com/kemalcr/kemal/pull/740). Thanks @sdogruyol :pray:

```crystal
post "/" do |env|
  raw = env.params.raw_body  # raw body, multiple handlers can call it
  env.params.body["name"]    # parsed body
end
```

- Fix OverrideMethodHandler route cache bug when using `_method` override [#741](https://github.com/kemalcr/kemal/pull/741), [#742](https://github.com/kemalcr/kemal/pull/742). Thanks @skojin and @sdogruyol :pray:

# 1.9.0 (28-01-2026)

- Crystal 1.19.0 support :tada:
- ***(SECURITY)*** Limit maximum request body size to avoid DoS attacks [#730](https://github.com/kemalcr/kemal/pull/730). Thanks @sdogruyol :pray:
- Optimize JSON parameter parsing by directly using the request body IO. Thanks @sdogruyol :pray:

# 1.8.0 (07-11-2025)

- Enhance HEAD request handling by caching GET route lookups and optimize path construction using string interpolation for improved performance [#728](https://github.com/kemalcr/kemal/pull/728). Thanks @sdogruyol :pray:
- Improve error messages [#726](https://github.com/kemalcr/kemal/pull/726). Thanks @sdogruyol :pray:
- Optimize route and websocket lookups by caching results to reduce redundant processing in the HTTP server context [#725](https://github.com/kemalcr/kemal/pull/725). Thanks @sdogruyol :pray:
- Replace full-flush Route cache with LRU and add a configurable max cache size [#724](https://github.com/kemalcr/kemal/pull/724). Thanks @sdogruyol :pray:

# 1.7.3 (02-10-2025)

- Refactor [#719](https://github.com/kemalcr/kemal/pull/719). Thanks @sdogruyol :pray:
- Improve Kemal test suite. Thanks @sdogruyol :pray:

# 1.7.2 (04-08-2025)

- Move Kemal::Handler logic into separate module [#717](https://github.com/kemalcr/kemal/pull/717). Thanks @syeopite :pray:
- Refactor server binding logic to avoid binding in test environment [#719](https://github.com/kemalcr/kemal/pull/719). Thanks @sdogruyol :pray:

# 1.7.1 (14-04-2025)

- Improve `StaticFileHandler` to align with latest Crystal implementation [#711](https://github.com/kemalcr/kemal/pull/711). Thanks @sdogruyol :pray:

# 1.7.0 (14-04-2025)

- ***(SECURITY)*** Fix a Path Traversal Security issue in `StaticFileHandler`. [See](https://packetstorm.news/files/id/190294/) for more details. Thanks a lot @ahmetumitbayram :pray:
- Crystal 1.16.0 support :tada:
- Add ability to add handlers for raised exceptions [#688](https://github.com/kemalcr/kemal/pull/688). Thanks @syeopite :pray:

```crystal
require "kemal"

class NewException < Exception
end

get "/" do | env |
  raise NewException.new()
end

error NewException do | env |
  "An error occured!"
end

Kemal.run
```

- Add `all_files` method to `params` to support multiple file uploads in names ending with `[]` [#701](https://github.com/kemalcr/kemal/pull/701). Thanks @sdogruyol :pray:

```crystal
images = env.params.all_files["images[]"]?
```

- Embrace Crystal standard Log for logging [#705](https://github.com/kemalcr/kemal/pull/705). Thanks @hugopl :pray:
- Cleanup temporary files for file uploads [#707](https://github.com/kemalcr/kemal/pull/707). Thanks @sdogruyol :pray:
- Implement multiple partial ranges [#708](https://github.com/kemalcr/kemal/pull/708). Thanks @sdogruyol :pray:

# 1.6.0 (12-10-2024)

- Crystal 1.14.0 support :tada:
- Windows support [#690](https://github.com/kemalcr/kemal/pull/690). Thanks @sdogruyol :pray:
- Directory Listing: Add UTF-8 Charset to the response Content type [#679](https://github.com/kemalcr/kemal/pull/679). Thanks @alexkutsan @Sija :pray:
- Use context instead of response in static_headers helper [#681](https://github.com/kemalcr/kemal/pull/681). Thanks @sdogruyol :pray:

# 1.5.0 (10-04-2024)

- Crystal 1.12.0 support :tada:
- Allow HTTP::Server::Context#redirect to take an URL [#659](https://github.com/kemalcr/kemal/pull/659). Thanks @xendk :pray:
- Bump `exception_page` dependency [#669](https://github.com/kemalcr/kemal/pull/669). Thanks @Sija :pray:
- Add message support to `Kemal::Exceptions::CustomException` [#671](https://github.com/kemalcr/kemal/pull/671). Thanks @sdogruyol :pray:
- Add `Date` header to HTTP responses [#676](https://github.com/kemalcr/kemal/pull/676). Thanks @Sija :pray:

# 1.4.0 (15-04-2023)

- Crystal 1.8.0 support :tada:
- Fix multiple logger handlers when custom logger is used [#653](https://github.com/kemalcr/kemal/pull/653). Thanks @aravindavk :pray:
- Add `Kemal::OverrideMethodHandler` [#651](https://github.com/kemalcr/kemal/pull/651). Thanks @sdogruyol :pray:
- `HeadRequestHandler`: run GET handler and don't return the body [#655](https://github.com/kemalcr/kemal/pull/655). Thanks @compumike :pray:

# 1.3.0 (09-10-2022)

- Crystal 1.6.0 support :tada:
- Disable signal trap for usage Kemal with other tools [#642](https://github.com/kemalcr/kemal/pull/642). Thanks @le0pard :pray:
- Bump exception_page shard to v0.3.0 [#645](https://github.com/kemalcr/kemal/pull/645). Thanks @Sija :pray:
- ***(Security)*** Omitting filters fix for lowercase methods requests [#647](https://github.com/kemalcr/kemal/pull/647). Thanks @sdogruyol @SlayerShadow :pray:

# 1.2.0 (07-07-2022)

- Crystal 1.5.0 support :tada:
- Eliminated several seconds of delay when loading big mp4 file. Thanks @Athlon64 :pray:
- Fix `content_for` failing to capture the correct block input [#639](https://github.com/kemalcr/kemal/pull/639). Thanks @sdogruyol :pray:
- Closes response by default in `HTTP::Server::Context#redirect` [#641](https://github.com/kemalcr/kemal/pull/641). Thanks @cyangle :pray:
- Enable option for `index.html` to be a directories default [#640](https://github.com/kemalcr/kemal/pull/640). Thanks @ukd1 :pray:

  You can enable it via:

  ```crystal
  serve_static({"dir_index" => true})
  ```

# 1.1.2 (24-02-2022)

- Fix content rendering [#631](https://github.com/kemalcr/kemal/pull/631). Thanks @matthewmcgarvey :pray:

# 1.1.1 (22-02-2022)

- Remove Kilt [#618](https://github.com/kemalcr/kemal/pull/618). Thanks @sdogruyol :pray:
- Ignore `HTTP::Server::Response` patching for crystal >= 1.3.0 [#628](https://github.com/kemalcr/kemal/pull/628). Thanks @SamantazFox :pray:

# 1.1.0 (02-09-2021)

- You can now set your own application name for startup message [#606](https://github.com/kemalcr/kemal/pull/606). Thanks @aravindavk :pray:
- Add array of paths support for before/after filters [#605](https://github.com/kemalcr/kemal/pull/605). Thanks @sdogruyol :pray:
- Fixed executing filters when before and after is defined at the same time [#612](https://github.com/kemalcr/kemal/pull/612). Thanks @mamantoha :pray:
-  Set content type to text/html for 500 exceptions [#616](https://github.com/kemalcr/kemal/pull/616). Thanks @sdogruyol :pray:

# 1.0.0 (22-03-2021)

- Crystal 1.0.0 support :tada:
- Update Radix to use latest 0.4.0 [#596](https://github.com/kemalcr/kemal/pull/596). Thanks @luislavena :pray:
- Use latest version of Ameba dependency (dev) [#597](https://github.com/kemalcr/kemal/pull/597). Thanks @luislavena :pray:
- Fix `StaticFileHandler` failing spec [#599](https://github.com/kemalcr/kemal/pull/599). Thanks @jinn999 :pray:

# 0.27.0 (28-11-2020)

- Crystal 0.35.x support :tada: Thanks @bcardiff :pray:
- Fix issues with responding with long strings [#576](https://github.com/kemalcr/kemal/pull/576). Thanks @mamantoha :pray:
- Fix broken WebSocket support in 0.35.0 [#577](https://github.com/kemalcr/kemal/pull/577). Thanks @mamantoha :pray:
- Allow to set optional response body on redirects [#561](https://github.com/kemalcr/kemal/pull/561). Thanks @mamantoha :pray:

# 0.26.1 (01-12-2019)

- Fix process request when a response already closed [#550](https://github.com/kemalcr/kemal/pull/550). Thanks @mamantoha :pray:
- Switch to new Ameba repository [#549](https://github.com/kemalcr/kemal/pull/549). Thanks @mamantoha :pray:
- Check for `KEMAL_ENV` variable already in `Config#initialize`[#552](https://github.com/kemalcr/kemal/pull/552). Thanks @Sija :pray:
- Cleanup Ameba warnings [#551](https://github.com/kemalcr/kemal/pull/551). Thanks @Sija :pray:
- Flush io buffer after each write to log [#554](https://github.com/kemalcr/kemal/pull/554). Thanks @mang :pray:

# 0.26.0 (05-08-2019)

- Crystal 0.30.0 support :tada: [#548](https://github.com/kemalcr/kemal/pull/548) and [#544](https://github.com/kemalcr/kemal/pull/544). Thanks @bcardiff and @straight-shoota :pray:
- Add support for serving files greater than 2^31 bytes [#546](https://github.com/kemalcr/kemal/pull/546). Thanks @omarroth :pray:
- Properly measure request time using `Time.monotonic` [#527](https://github.com/kemalcr/kemal/pull/527). Thanks @spinscale :pray:

# 0.25.2 (08-02-2019)

- Add option to config to parse or not command line parameters [#483](https://github.com/kemalcr/kemal/pull/483). Thanks @diegogub :pray:
- Allow to set filename for `send_file` [#512](https://github.com/kemalcr/kemal/pull/512). Thanks @mamantoha :pray:

  ```crystal
  send_file env, "./asset/image.jpeg", filename: "image.jpg"
  ```

- Set `status_code` before response [#513](https://github.com/kemalcr/kemal/pull/513). Thanks @mamantohoa :pray:
- Use Crystal MIME registry. [#516](https://github.com/kemalcr/kemal/pull/516) Thanks @Sija :pray:

# 0.25.1 (06-10-2018)

- Fix `params.files` memoization [#503](https://github.com/kemalcr/kemal/pull/503). Thanks @mamantoha :pray:

# 0.25.0 (05-10-2018)

- Crystal 0.27.0 support.
-  *[breaking change]* Added back `env.params.files`.

  Here's a fully working sample for reading a image file upload `image1` and saving it under `public/uploads`.

  ```crystal
  post "/upload" do |env|
    file = env.params.files["image1"].tempfile
    file_path = ::File.join [Kemal.config.public_folder, "uploads/", File.basename(file.path)]
    File.open(file_path, "w") do |f|
      IO.copy(file, f)
    end
    "Upload ok"
  end
  ```

  To test

  `curl -F "image1=@/Users/serdar/Downloads/kemal.png" http://localhost:3000/upload`

- Cache HTTP routes to increase performance :rocket: [#493](https://github.com/kemalcr/kemal/pull/493)

# 0.24.0 (14-08-2018)

- *[breaking change]* Removed `env.params.files`. You can use Crystal's built-in `HTTP::FormData.parse` instead:

  ```crystal
  post "/upload" do |env|
    HTTP::FormData.parse(env.request) do |upload|
      filename = file.filename

      if !filename.is_a?(String)
        "No filename included in upload"
      else
        file_path = ::File.join [Kemal.config.public_folder, "uploads/", filename]
        File.open(file_path, "w") do |f|
        IO.copy(file.tmpfile, f)
      end
      "Upload OK"
    end
  end
  ```

- *[breaking change]* From now on to access dynamic url params in a WebSocket route you have to use:

  ```crystal
  ws "/:id" do |socket, context|
    id = context.ws_route_lookup.params["id"]
  end
  ```

- *[breaking change]* Removed `_method` magic param.
- Added new exception page [#466](https://github.com/kemalcr/kemal/pull/466). Thanks @mamantoha 🙏
- Support custom port binding. Thanks @straight-shoota 🙏

  ```crystal
  Kemal.run do |config|
    server = config.server.not_nil!
    server.bind_tcp "127.0.0.1", 3000, reuse_port: true
    server.bind_tcp "0.0.0.0", 3001, reuse_port: true
  end
  ```

# 0.23.0 (17-06-2018)

- Crystal 0.25.0 support 🎉
- Add `Kemal::Context.get?` to safely access context storage :sunglasses:
- [Security] Don't serve 404 image dynamically :thumbsup:
- Disable `X-Powered-By` header [#449](https://github.com/kemalcr/kemal/pull/449). Thanks @Blacksmoke16 🙏

# 0.22.0 (29-12-2017)

- Crystal 0.24.1 support 🎉
- Only return string from route.[#408](https://github.com/kemalcr/kemal/pull/408) thanks @crisward 🙏
- Don't crash on empty path when compiled in --release. [#407](https://github.com/kemalcr/kemal/pull/407) thanks @crisward 🙏
- Rename `Kemal::CommonLogHandler` to `Kemal::LogHandler` and `Kemal::CommonExceptionHandler` to `Kemal::ExceptionHandler`.
- Allow videos to be opened with correct mime type. [#406](https://github.com/kemalcr/kemal/pull/406) thanks @crisward 🙏
- Add webm mime type.[#413](https://github.com/kemalcr/kemal/pull/413) thanks @reindeer-cafe 🙏

# 0.21.0 (05-09-2017)

- Dynamically insert handlers :muscle: Fixes [#376](https://github.com/kemalcr/kemal/pull/376).
- Add context to WebSocket. This allows one to use `HTTP::Server::Context` in `ws` declarations :heart_eyes: Fixes [#349](https://github.com/kemalcr/kemal/pull/349).

  ```crystal
  ws "/:room_name" do |socket, env|
    env.params.url["room_name"]
  end
  ```

- Add support for customizing the headers of built-in `Kemal::StaticFileHandler` :hammer: Useful for supporting `CORS` for single page applications :clap:

  ```crystal
  static_headers do |response, filepath, filestat|
    if filepath =~ /\.html$/
      response.headers.add("Access-Control-Allow-Origin", "*")
    end
    response.headers.add("Content-Size", filestat.size.to_s)
  end
  ```

- Allow `%w` in Handler macros [#385](https://github.com/kemalcr/kemal/pull/385). Thanks @will :pray:
- Security: `X-Content-Type-Options: nosniff` for static files. Fixes [#379](https://github.com/kemalcr/kemal/issues/379). Thanks @crisward :pray:
- Performance: [Remove tempfile management to OS](https://github.com/kemalcr/kemal/commit/a1520de7ed3865fa73258343a80fad4f20666a99). This brings 10-15% performance boost to Kemal :rocket:

# 0.20.0 (01-07-2017)

- Crystal 0.23.0 support! As always, Kemal is compatible with the latest major release of Crystal 💎
- Great news everyone 🎉 All handlers are now completely ***customizable***!. Use the default `Kemal` handlers or go wild, it's all up to you ⛏

  ```crystal
  # Don't forget to add `Kemal::RouteHandler::INSTANCE` or your routes won't work!
  Kemal.config.handlers = [Kemal::InitHandler.new, YourHandler.new, Kemal::RouteHandler::INSTANCE]
  ```

  You can also insert a handler into a specific position.

  ```crystal
  # This adds MyCustomHandler instance to 1 position.
  # Be aware that the index starts from 0.
  add_handler MyCustomHandler.new, 1
  ```

- Updated [Kilt](https://github.com/jeromegn/kilt) to v0.4.0.
- Make `Route` a `Struct`. This improves the performance of route declarations.

# 0.19.0 (09-05-2017)

-  Return no body for head route fixes [#323](https://github.com/kemalcr/kemal/issues/323). (thanks @crisward)
-  Update Radix to `v0.3.8`. (thanks @waghanza)
-  User defined context store types. (thanks @neovitange)

  ```crystal
  class User
    property name
  end

  add_context_storage_type(User)
  ```

- Prevent `send_file` returning filesize. (thanks @crisward)
- Don't call setup in `config#add_filter_handler` fixes [#338](https://github.com/kemalcr/kemal/issues/338).

# 0.18.3 (07-03-2017)

- Remove `Gzip::Header` monkey patch since it's fixed in `Crystal 0.21.1`.

# 0.18.2 (24-02-2017)

- Fix Gzip in Kemal Seems broken for static files [#316](https://github.com/kemalcr/kemal/issues/316). This was caused by `Gzip::Writer` in `Crystal 0.21.0` and currently mitigated by monkey patching `Gzip::Header`.

# 0.18.1 (21-02-2017)

- Crystal 0.21.0 support
- Drop `multipart.cr` dependency. `multipart` support is now built-into Crystal <3
- Since Crystal 0.21.0 comes built-in with `multipart` there are some improvements and deprecations.
- `meta` has been removed from `FileUpload` and it has the following properties:
  + `tmpfile`: This is temporary file for file upload. Useful for saving the upload file.
  + `filename`: File name of the file upload. (logo.png, images.zip e.g)
  + `headers`: Headers for the file upload.
  + `creation_time`: Creation time of the file upload.
  + `modification_time`: Last Modification time of the file upload.
  + `read_time`: Read time of the file upload.
  + `size`: Size of the file upload.

# 0.18.0 (11-02-2017)

- Simpler file upload. File uploads can now be access from `HTTP::Server::Context` like `env.params.files["filename"]`, which exposes following properties.
  + `tmpfile`: This is temporary file for file upload. Useful for saving the upload file.
  + `tmpfile_path`: File path of `tmpfile`.
  + `filename`: File name of the file upload. (logo.png, images.zip e.g)
  + `meta`: Meta information for the file upload.
  + `headers`: Headers for the file upload.

  Here's a fully working sample for reading a image file upload `image1` and saving it under `public/uploads`.

  ```crystal
  post "/upload" do |env|
    file = env.params.files["image1"].tmpfile
    file_path = ::File.join [Kemal.config.public_folder, "uploads/", file.filename]
    File.open(file_path, "w") do |f|
      IO.copy(file, f)
    end
    "Upload ok"
  end
  ```

  To test

  `curl -F "image1=@/Users/serdar/Downloads/kemal.png" http://localhost:3000/upload`

- RF7233 support a.k.a file streaming. [#299](https://github.com/kemalcr/kemal/pull/299) (thanks @denysvitali)
- Update Radix to 0.3.7. Fixes [#293](https://github.com/kemalcr/kemal/issues/293)
- Configurable startup / shutdown logging. [#291](https://github.com/kemalcr/kemal/issues/291) and [#292](https://github.com/kemalcr/kemal/issues/292) (thanks @twisterghost).

# 0.17.5 (09-01-2017)

- Update multipart.cr to 0.1.2. Fixes #285 related to multipart.cr

# 0.17.4 (24-12-2016)

- Support for Crystal 0.20.3
- Add `Kemal.stop`. Fixes [#269](https://github.com/kemalcr/kemal/issues/269).
- `HTTP::Handler` is not a class anymore, it's a module. See https://github.com/crystal-lang/crystal/releases/tag/0.20.3

# 0.17.3 (03-12-2016)

- Handle missing 404 image. Fixes [#263](https://github.com/kemalcr/kemal/issues/263)
- Remove basic auth middleware from core and move to [kemalcr/kemal-basic-auth](https://github.com/kemalcr/kemal-basic-auth).

# 0.17.2 (25-11-2016)

- Use `body.gets_to_end` for `parse_json`. Fixes #260.
- Update Radix to 0.3.5 and lock pessimistically. (thanks @luislavena)

# 0.17.1 (24-11-2016)

- Treat `HTTP::Request` body as an `IO`. Fixes [#257](https://github.com/kemalcr/kemal/issues/257)

# 0.17.0 (23-11-2016)

- Reimplemented Request middleware / filter routing.

  Now all requests will first go through the Middleware stack then Filters (`before_*`) and will finally reach the matching route.

  Which is illustrated as: `Request -> Middleware -> Filter -> Route`

- Rename `return_with` as `halt`.
- Route declaration must start with `/`. Fixes [#242](https://github.com/kemalcr/kemal/issues/242)
- Set default exception `Content-Type` to `text/html`. Fixes [#202](https://github.com/kemalcr/kemal/issues/242)
- Add `only` and `exclude` paths for `Kemal::Handler`. This change requires that all handlers must inherit from `Kemal::Handler`.

  For example this handler will only work on `/` path. By default the HTTP method is `GET`.

  ```crystal
  class OnlyHandler < Kemal::Handler
    only ["/"]

    def call(env)
      return call_next(env) unless only_match?(env)
      puts "If the path is / i will be doing some processing here."
    end
  end
  ```

  The handlers using `exclude` will work on the paths that isn't specified. For example this handler will work on any routes other than `/`.

  ```crystal
  class ExcludeHandler < Kemal::Handler
    exclude ["/"]

    def call(env)
      return call_next(env) unless only_match?(env)
      puts "If the path is NOT / i will be doing some processing here."
    end
  end
  ```

- Close response on `halt`. (thanks @samueleaton).
- Update Radix to `v0.3.4`.
- `error` handler now also yields error. For example you can get the error mesasage like:

  ```crystal
  error 500 do |env, err|
    err.message
  end
  ```

- Update `multipart.cr` to `v0.1.1`

# 0.16.1 (12-10-2016)

- Improved Multipart support with more info on parsed files. `parse_multipart(env)` now yields an `UploadFile` object which has the following properties: `field`, `data`, `meta` and `headers`.

  ```crystal
  post "/upload" do |env|
    parse_multipart(env) do |f|
      image1 = f.data if f.field == "image1"
      image2 = f.data if f.field == "image2"
      puts f.meta
      puts f.headers
      "Upload complete"
    end
  end
  ```

# 0.16.0

- Multipart support <3 (thanks @RX14). Now you can handle file uploads.

  ```crystal
  post "/upload" do |env|
    parse_multipart(env) do |field, data|
      image1 = data if field == "image1"
      image2 = data if field == "image2"
      "Upload complete"
    end
  end
  ```

- Make session configurable. Now you can specify session name and expire time with:

  ```crystal
  Kemal.config.session["name"] = "your_app"
  Kemal.config.session["expire_time"] = 48.hours
  ```

- Session now supports more types. (`String`, `Int32`, `Float64`, `Bool`)
- Add `gzip` helper to enable / disable gzip compression on responses.
- Static file caching with etag and gzip (thanks @crisward)
- `Kemal.run` now accepts port to listen.

# 0.15.1 (05-09-2016)

- Don't forget to `call_next` on `NullLogHandler`

# 0.15.0 (03-09-2016)

- Add context store.
- `KEMAL_ENV` respects to `Kemal.config.env` and needs to be explicitly set.
- `Kemal::InitHandler` is introduced. Adds initial configuration, headers like `X-Powered-By`.
- Add `send_file` to helpers.
- Add mime types.
- Fix parsing JSON params when "charset" is present in `Content-Type` header.
- Use http-only cookie for session.
- Inject `STDOUT` by default in `CommonLogHandler`.
