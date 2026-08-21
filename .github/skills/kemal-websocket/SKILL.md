---
name: kemal-websocket
description: Implementing real-time bi-directional communication with WebSockets in Kemal, origin security, and lifecycle management.
license: MIT
---

# Kemal WebSocket Integration

This skill provides expert guidance on using WebSockets for real-time features in Kemal, with version-aware origin security guidance, strictly following patterns from [`kemal-by-example/real-time-dashboard`](https://github.com/sdogruyol/kemal-by-example/tree/master/real-time-dashboard) and [`kemal-by-example/twitter-clone`](https://github.com/sdogruyol/kemal-by-example/tree/master/twitter-clone).

## Version Notes

- **Default Origin policy changed on master:** with an empty `websocket_allowed_origins` (the default), Kemal master enforces same-origin and rejects missing or mismatched `Origin` headers with `403 Forbidden`; releases up to 1.12.0 allow **all** origins (CSWSH risk — configure an allowlist explicitly, see below).
- `websocket_allowed_origins = ["*"]` opt-in allow-all: Kemal master only.
- Non-GET upgrade rejection (RFC 6455 §4.1, `405 Method Not Allowed` + `Allow: GET`) and explicit `Connection: close` after a rejected handshake: Kemal master only.

## Core Mandates

- **WebSocket Route Definition:** Use the `ws` helper to define WebSocket endpoints:

  ```crystal
  ws "/socket" do |socket, env|
    # Socket lifecycle callbacks
  end
  ```

- **Origin Validation & CSWSH Security:**
  - **CRITICAL ON STABLE RELEASES (1.12.0 and earlier):** An empty `Kemal.config.websocket_allowed_origins = [] of String` (default) **permits all origins** (`return true if allowed.empty?`).
    To protect against Cross-Site WebSocket Hijacking (CSWSH) in production on these releases, you **MUST explicitly configure allowed origins**:

    ```crystal
    # MANDATORY on 1.12.0 and earlier to protect against CSWSH:
    Kemal.config.websocket_allowed_origins = %w[https://myapp.com http://localhost:3000]
    ```

  - **ON KEMAL MASTER (not yet in a stable release):** An empty `websocket_allowed_origins` defaults to strict **same-origin** enforcement (matching request `Host`). Missing or mismatched `Origin` headers are rejected with `403 Forbidden`. To explicitly allow all origins on master:

    ```crystal
    # Kemal master only — opt-in allow-all:
    Kemal.config.websocket_allowed_origins = ["*"]
    ```

- **Protocol Compliance (RFC 6455 §4.1) — *[Kemal master only]*:**
  - On Kemal master, WebSocket upgrade handshakes require the `GET` method. Non-GET upgrade requests (`POST`, `QUERY`, etc.) are automatically rejected with `405 Method Not Allowed`, `Allow: GET`, and `Connection: close`.
  - Failed handshakes close the connection immediately to prevent WebSocket connection smuggling.

- **Socket Lifecycle Callbacks:**
  - `socket.on_message`: Handle incoming text messages from client
  - `socket.on_close`: Handle socket disconnection and perform cleanup
  - `socket.on_ping` / `socket.on_pong`: Handle heartbeat signals

- **Concurrency Safety:** Always protect shared socket collections with a `Mutex`:

  ```crystal
  class Hub
    @sockets = Array(HTTP::WebSocket).new
    @mutex = Mutex.new

    def register(socket)
      @mutex.synchronize { @sockets << socket }
    end

    def unregister(socket)
      @mutex.synchronize { @sockets.delete(socket) }
    end
  end
  ```

- **Error Handling:** Rescue `IO::Error | Socket::Error` when sending to sockets and unregister closed sockets.

## Patterns from Source Code

### Centralized WebSocket Hub (real-time-dashboard/src/services/dashboard_hub.cr)

```crystal
require "kemal"

module RealTimeDashboard
  class DashboardHub
    # NOTE: Do not `include JSON::Serializable` here — it removes the default
    # constructor, and sockets/mutexes are not serializable anyway. Serialize a
    # plain stats payload (e.g. `{"total_requests" => total_requests}.to_json`)
    # when broadcasting instead.
    getter total_requests : Int64 = 0_i64
    getter active_users : Int32 = 0

    @sockets = Array(HTTP::WebSocket).new
    @mutex = Mutex.new

    def register(socket : HTTP::WebSocket)
      @mutex.synchronize { @sockets << socket }
    end

    def unregister(socket : HTTP::WebSocket)
      @mutex.synchronize { @sockets.delete(socket) }
    end

    def broadcast(message : String)
      @mutex.synchronize do
        @sockets.reject! do |socket|
          begin
            socket.send(message)
            false
          rescue IO::Error | Socket::Error
            true # Remove failed socket
          end
        end
      end
    end
  end
end
```

### WebSocket Route Setup with Origin Security

```crystal
require "kemal"

# Configure allowed origins explicitly (mandatory on 1.12.0 and earlier for security, recommended everywhere)
Kemal.config.websocket_allowed_origins = %w[http://127.0.0.1:3000 http://localhost:3000]

HUB = RealTimeDashboard::DashboardHub.new

ws "/dashboard/socket" do |socket, env|
  HUB.register(socket)

  socket.on_message do |msg|
    # Handle incoming client messages (spawn long-running work to avoid blocking fiber)
    spawn do
      # process msg
    end
  end

  socket.on_close do
    HUB.unregister(socket)
  end
end
```

## Best Practices

- **Security First:** Always configure `Kemal.config.websocket_allowed_origins` explicitly in production. Origin validation is a browser boundary, not authentication/authorization.
- **Mutex Synchronization:** Wrap all modifications and iterations over socket lists in `@mutex.synchronize`.
- **Selective Rejection:** Use `@sockets.reject!` inside broadcast loops to cleanly strip dead sockets without deadlocks.
- **Graceful Teardown:** Unregister sockets in `on_close` callbacks.

## When to Use

- When building real-time bi-directional chat applications, collaborative tools, or active telemetry dashboards.
- When client and server communicate via continuous socket connections.
