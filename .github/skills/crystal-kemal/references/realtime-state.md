# Kemal state and realtime reference

## File uploads

Uploaded files are available through `env.params.files`; useful properties include `filename`, `tempfile`, `size`, and `headers`.

Before saving:

- Ensure the expected parameter exists.
- Enforce size limits.
- Allow-list expected types/extensions when appropriate.
- Generate a server-controlled destination name.
- Validate path containment.
- Do not trust the client filename as a storage path.
- Keep sensitive uploads outside public static roots.

Tune `Kemal.config.max_multipart_form_field_size` to the intended upload profile.

## Sessions

Session support is provided by `kemal-session`, not core Crystal language semantics. Keep session secrets outside source control and select a storage engine suitable for the deployment topology. In-memory storage is suitable for development/testing but is not durable shared production storage.

Follow the installed `kemal-session` version for CSRF/session APIs rather than inventing helper methods.

## WebSockets

```crystal
ws "/" do |socket|
  socket.on_message do |message|
    socket.send "Echo: #{message}"
  end
end
```

With context:

```crystal
ws "/:id" do |socket, context|
  id = context.ws_route_lookup.params["id"]
end
```

Configure browser WebSocket origin policy with
`Kemal.config.websocket_allowed_origins`.

On Kemal master (not yet in a stable release), an empty `websocket_allowed_origins` list enforces same-origin
WebSocket connections. On stable releases (1.12.0 and earlier), an empty list permits all origins by default.

Use an explicit allowlist when trusted cross-origin browser clients need access (mandatory on 1.12.0 and earlier for CSWSH protection):

```crystal
Kemal.config.websocket_allowed_origins = %w[
  https://myapp.com
  http://localhost:3000
]
```

To explicitly allow connections from any origin (on master):

```crystal
Kemal.config.websocket_allowed_origins = ["*"]
```

Origin validation is an additional browser security boundary and does not
replace application authentication or authorization.

Handle disconnects and lifecycle/shutdown behavior for long-lived connections.

## Server-Sent Events

Use SSE for one-way server-to-client streaming:

```crystal
sse "/events" do |stream, env|
  stream.send("tick", event: "tick", id: 1)
end
```

Use WebSockets instead when full duplex is required. Avoid busy loops and account for proxy buffering, disconnects, and long-lived timeouts.

## Caching

When using `kemal-cache`, register its handler before the routes it should affect. Do not blindly cache authenticated, cookie-sensitive, or user-specific responses. Cache correctness and isolation take precedence over hit rate. Verify third-party shard compatibility with the project's supported versions.
