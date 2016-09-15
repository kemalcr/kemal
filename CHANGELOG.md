# Next

- Add `gzip` helper to enable / disable gzip compression on responses.

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