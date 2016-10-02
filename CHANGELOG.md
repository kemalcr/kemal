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

# 0.15.1 (05-09-2015)

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