---
name: kemal-websocket
description: Implementing real-time bi-directional communication with WebSockets in Kemal, origin security, and lifecycle management.
---

# Kemal WebSocket Integration

This skill provides expert guidance on using WebSockets for real-time features in Kemal, with precise security guidance for Kemal 1.12.0 release versus Kemal master, strictly following patterns from `src/kemal-by-example/real-time-dashboard/` and `src/kemal-by-example/twitter-clone/`.

## Compatibility Matrix

| Feature | Kemal 1.12.0 (Release) | Kemal Master (Unreleased / Next) |
| :--- | :--- | :--- |
| `ws` Route Helper & Lifecycle | Supported | Supported |
| Origin Validation Config (`websocket_allowed_origins`) | Supported | Supported |
| **Default Origin Policy** (`allowed_origins = []`) | **Allow-All (Open by default)** | **Same-Origin (Strict by default)** |
| Allow-All Escape Hatch (`["*"]`) | N/A (default is already open) | Supported (opt-in allow-all) |
| Non-GET Upgrade Rejection (RFC 6455 §4.1) | **Not available** (returns standard error) | Supported (`405 Method Not Allowed` + `Allow: GET`) |
| Connection Teardown on Handshake Failure | Standard close | Explicit `Connection: close` (anti-smuggling) |

## Core Mandates

- **WebSocket Route Definition:** Use the `ws` helper to define WebSocket endpoints:

  ```crystal
  ws "/socket" do |socket, env|
    # Socket lifecycle callbacks
  end
  ```

- **Origin Validation & CSWSH Security:**
  - **CRITICAL ON KEMAL 1.12.0 RELEASE:** An empty `Kemal.config.websocket_allowed_origins = [] of String` (default) **permits all origins** (`return true if allowed.empty?`).
    To protect against Cross-Site WebSocket Hijacking (CSWSH) in production on Kemal 1.12.0, you **MUST explicitly configure allowed origins**:

    ```crystal
    # MANDATORY on Kemal 1.12.0 to protect against CSWSH:
    Kemal.config.websocket_allowed_origins = %w[https://myapp.com http://localhost:3000]
    ```

  - **ON KEMAL MASTER (Unreleased / Next):** An empty `websocket_allowed_origins` defaults to strict **same-origin** enforcement (matching request `Host`). Missing or mismatched `Origin` headers are rejected with `403 Forbidden`. To explicitly allow all origins on master:

    ```crystal
    # Kemal master / upcoming 1.13.0 opt-in allow-all:
    Kemal.config.websocket_allowed_origins = ["*"]
    ```

- **Protocol Compliance (RFC 6455 §4.1) — *[Kemal Master / Unreleased]*:**
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
    include JSON::Serializable

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

# Configure allowed origins explicitly (mandatory on 1.12.0 for security, recommended everywhere)
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
