---
name: kemal-sse
description: Real-time Server-Sent Events (SSE) streaming in Kemal 1.12+, following established project patterns.
license: MIT
---

# Kemal Server-Sent Events (SSE)

This skill provides expert guidance on implementing real-time unidirectional event streaming using Kemal's built-in `sse` helper (available in Kemal 1.12.0+).

## Version Notes

- `sse` route helper and `Kemal::EventStream` (named events, `id:`, `retry:`): since Kemal 1.12.0.
- SSE injection protection (CR/LF rejected in `event`/`id`, CRLF normalization in `data` and comments) and the `retry` field Int32 overflow fix: since Kemal 1.13.0.
- Negative `retry` spans are omitted from the output (clients discard non-digit values): unreleased, after Kemal 1.13.0.

## Core Mandates

- **SSE Route Definition (Kemal 1.12.0+):** Use the `sse` helper block to define an SSE endpoint:

  ```crystal
  sse "/events" do |stream, env|
    stream.send("hello world")
  end
  ```

- **Sending Named Events & Security:** Pass `event`, `id`, and optional `retry` (`Time::Span`) keyword arguments:

  ```crystal
  sse "/notifications" do |stream, env|
    stream.send({"message" => "New alert"}.to_json, event: "alert", id: 101, retry: 5.seconds)
  end
  ```

  *Security Note (Kemal 1.13.0+)*: `Kemal::EventStream` prevents SSE injection by rejecting raw newlines in `event` and `id` arguments, and automatically normalizes CRLF sequences in `data` and `comment`.

- **Streaming Loops & Channels:** Use Crystal channels or keep-alive loops for streaming events:

  ```crystal
  sse "/stream" do |stream, env|
    loop do
      sleep 1.seconds
      stream.send(Time.utc.to_s, event: "time")
    rescue IO::Error
      break # Connection closed by client
    end
  end
  ```

## Patterns from Source Code

### Real-Time Live Updates with Channel / Loop

```crystal
require "kemal"

sse "/live-ticks" do |stream, env|
  count = 0_i64
  loop do
    count += 1
    stream.send(
      {"count" => count, "timestamp" => Time.utc.to_s}.to_json,
      event: "tick",
      id: count
    )
    sleep 1.seconds
  rescue IO::Error
    # Client disconnected, gracefully terminate streaming loop
    break
  end
end

Kemal.run
```

### Pub/Sub Broadcasting via SSE Stream Manager

```crystal
require "kemal"

class SseHub
  @streams = Array(Kemal::EventStream).new
  @mutex = Mutex.new

  def register(stream : Kemal::EventStream)
    @mutex.synchronize { @streams << stream }
  end

  def unregister(stream : Kemal::EventStream)
    @mutex.synchronize { @streams.delete(stream) }
  end

  def broadcast(data : String, event : String? = nil)
    @mutex.synchronize do
      @streams.reject! do |stream|
        begin
          stream.send(data, event: event)
          false
        rescue IO::Error
          true # Remove closed connections
        end
      end
    end
  end
end

HUB = SseHub.new

sse "/subscribe" do |stream, env|
  HUB.register(stream)
  # Block while connection remains open
  begin
    sleep
  ensure
    HUB.unregister(stream)
  end
end

post "/publish" do |env|
  message = env.params.body["message"]? || ""
  HUB.broadcast(message, event: "news")
  env.json({status: "ok"})
end

Kemal.run
```

## Best Practices

- **Connection Cleanup:** Always handle client disconnects gracefully by rescuing `IO::Error` or using an `ensure` block.
- **Content Type:** Kemal automatically sets `Content-Type: text/event-stream` and `Cache-Control: no-cache` headers for SSE routes.
- **JSON Serialization:** Convert Crystal data structures to JSON strings using `.to_json` before passing to `stream.send(...)`.
- **API Response Helpers:** For JSON response formatting and error handling on companion HTTP routes (e.g. `post "/publish"`), follow the patterns in [`kemal-json`](../kemal-json/SKILL.md).
- **Prefer SSE over WebSockets for Uni-directional Feeds:** Use SSE for live log feeds, dashboard metrics, and notifications where full bi-directional socket protocol overhead is unnecessary.

## When to Use

- When building real-time dashboards, log streaming, or live notification feeds.
- When client-to-server responses are handled via standard HTTP POST routes, while server-to-client updates stream via HTTP `text/event-stream`.
