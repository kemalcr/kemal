# Kemal operations reference

## Resource limits

Set application-specific limits rather than copying example values blindly:

```crystal
Kemal.config.max_request_body_size = 10 * 1024 * 1024
Kemal.config.max_multipart_form_field_size = 8 * 1024 * 1024
Kemal.config.max_ranges = 16 # Part limit per Range request (since 1.13.0; set to 0 to ignore Range headers)
```

Multipart limits apply to individual multipart fields/file parts according to current Kemal behavior.

## Security baseline

Typical controls include explicit WebSocket origins, disabled `X-Powered-By` header by default (`Kemal.config.powered_by_header = false` since 1.13.0), request/multipart/Range size limits, HTTPS, deliberate security headers, authorization on sensitive routes, server-controlled file paths, and protection of secrets.

Third-party security middleware may be appropriate, but verify maintenance status and compatibility before adding dependencies.

## Configuration

Common settings include environment, port, host binding, shutdown timeout, public folder, static serving, SSL certificate/key paths, logger, and rescue behavior. Use deployment configuration or secret stores for environment-specific secrets.

## Testing

Use `spec-kemal` and run `KEMAL_ENV=test crystal spec`. Cover route verbs, params, status/content type, authn/authz, middleware, errors, upload rejection, and realtime behavior where practical.

## Production builds

Typical optimized build:

```bash
crystal build --release src/my_app.cr -o bin/app
```

Static linking is platform/toolchain dependent; verify the actual deployment target. Keep builder/runtime images aligned with the project's supported Crystal version instead of pinning stale example tags.

## Reverse proxies

For nginx or other proxies:

- Preserve WebSocket upgrade headers.
- Set suitable read timeouts for WebSockets/SSE.
- Avoid unintended SSE buffering.
- Terminate TLS consistently.
- Decide deliberately whether static files and security headers are owned by the proxy or Kemal.

## Databases

Kemal does not replace database pool management. Follow the chosen database shard's API, keep credentials outside source, use bounded pools/timeouts, parameterized queries, and non-sensitive health responses.

## Common pitfalls

1. Reading JSON/query/form data from the wrong `env.params.*` collection.
2. Dropping brackets from repeated form keys such as `likes[]`.
3. Route shadowing due to definition order.
4. Treating `halt` as generic middleware control flow.
5. Forgetting `add_context_storage_type` for custom context types.
6. Putting business logic into ECR.
7. Using filters where reusable middleware is more appropriate.
8. Calling `call_next` after a deliberate short circuit.
9. Registering broad exception handlers before intended narrow handlers.
10. Leaving WebSocket origins open unintentionally.
11. Treating origin validation as authentication.
12. Saving client filenames directly.
13. Using only a `../` substring test as path-traversal defense.
14. Serving private uploads from the public directory.
15. Ignoring multipart field limits.
16. Hard-coding session or deployment secrets.
17. Using development-only session storage as durable production storage.
18. Ignoring lifecycle/timeouts for long-lived streams.
19. Copying stale deployment image/toolchain versions.
