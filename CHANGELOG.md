# 0.17.4 (24-12-2016)

- Support for Crystal 0.20.3
- Add `Kemal.stop`. Fixes #269.
- `HTTP::Handler` is not a class anymore, it's a module. See https://github.com/crystal-lang/crystal/releases/tag/0.20.3

# 0.17.3 (03-12-2016)

- Handle missing 404 image. Fixes #263
- Remove basic auth middleware from core and move to [kemalcr/kemal-basic-auth](https://github.com/kemalcr/kemal-basic-auth).

# 0.17.2 (25-11-2016)

- Use body.gets_to_end for parse_json. Fixes #260.
- Update Radix to 0.3.5 and lock pessimistically. (thanks @luislavena)

# 0.17.1 (24-11-2016)

- Treat `HTTP::Request` body as an `IO`. Fixes [#257](https://github.com/sdogruyol/kemal/issues/257)

# 0.17.0 (23-11-2016)

- Reimplemented Request middleware / filter routing. 

Now all requests will first go through the Middleware stack then Filters (before_*) and will finally reach the matching route.

Which is illustrated as,

```
Request -> Middleware -> Filter -> Route
```

- Rename `return_with` as `halt`.
- Route declaration must start with `/`.  Fixes [#242](https://github.com/sdogruyol/kemal/issues/242)
- Set default exception Content-Type to text/html. Fixes [#202](https://github.com/sdogruyol/kemal/issues/242)
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
- Update `Radix` to `v0.3.4`.
- `error` handler now also yields error. For example you can get the error mesasage like

```crystal
  error 500 do |env, err|
    err.message
  end
```

- Update `multipart.cr` to `v0.1.1`

# 0.16.1 (12-10-2016)

- Improved Multipart support with more info on parsed files. `parse_multipart(env)` now yields
an `UploadFile` object which has the following properties `field`,`data`,`meta`,`headers.	

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

- Make session configurable. Now you can specify session name and expire time wit

```crystal
Kemal.config.session["name"] = "your_app"
Kemal.config.session["expire_time"] = 48.hours
```

- Session now supports more types. (String, Int32, Float64, Bool)
- Add `gzip` helper to enable / disable gzip compression on responses.
- Static file caching with etag and gzip (thanks @crisward)
- `Kemal.run` now accepts port to listen.

# 0.15.1 (05-09-2016)

- Don't forget to call_next on NullLogHandler

# 0.15.0 (03-09-2016)

- Add context store
- `KEMAL_ENV` respects to `Kemal.config.env` and needs to be explicitly set.
- `Kemal::InitHandler` is introduced. Adds initial configuration, headers like `X-Powered-By`.
- Add `send_file` to helpers.
- Add mime types.
- Fix parsing JSON params when "charset" is present in "Content-Type" header.
- Use http-only cookie for session 
- Inject STDOUT by default in CommonLogHandler
