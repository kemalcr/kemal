---
name: kemal-json
description: Building JSON APIs with Kemal using built-in response helpers and established project patterns.
license: MIT
---

# Kemal JSON API Development

This skill provides expert guidance on building robust JSON APIs with Kemal, establishing the canonical patterns for JSON response helpers and strictly following patterns from [`kemal-by-example/json-api`](https://github.com/sdogruyol/kemal-by-example/tree/master/json-api).

## Version Notes

- `env.json` and `env.status` response helpers (symbol or integer statuses): since Kemal 1.10.
- Malformed request bodies (e.g. invalid JSON) are answered with `400 Bad Request` on Kemal master; earlier releases return `500`.

## Core Mandates

- **Dependencies:** Always `require "json"`.
- **Built-in Context Response Helpers (Kemal 1.10+):** Use Kemal's built-in `env.json` and status helpers for API responses:

  ```crystal
  # Basic JSON response (sets Content-Type to application/json; charset=utf-8 automatically)
  get "/api/users" do |env|
    env.json({users: %w[alice bob]})
  end

  # Symbol or integer HTTP status code with JSON:
  post "/api/users" do |env|
    env.status(:created).json({id: 1, name: "Alice"})
  end

  # Early halt with JSON:
  get "/api/protected" do |env|
    halt env.status(:unauthorized).json({error: "Unauthorized"}) unless authenticated?(env)
  end
  ```

- **Project JsonResponse Helpers (Custom Pattern):** When using standard project helpers for responses (found in `JsonApi::JsonResponse`):

  ```crystal
  module JsonApi
    module JsonResponse
      extend self

      def json(env : HTTP::Server::Context, status : Int32, payload : String)
        env.response.status_code = status
        env.response.content_type = "application/json; charset=utf-8"
        payload
      end

      def error(env : HTTP::Server::Context, status : Int32, message : String)
        json(env, status, {"error" => message}.to_json)
      end
    end
  end
  ```

- **Safe JSON Body Parsing:** Use `env.params.raw_body` or `read_json_object(env)` to safely parse JSON bodies and handle exceptions:

  ```crystal
  private def read_json_object(env : HTTP::Server::Context) : Hash(String, JSON::Any)?
    raw = env.params.raw_body
    return nil if raw.strip.empty?
    parsed = JSON.parse(raw)
    parsed.as_h?
  rescue JSON::ParseException
    nil
  end
  ```

- **Serialization:** Models should provide a `to_h` method. Use `model.to_h` or `model.to_h.to_json` for responses.

## Patterns from Source Code

### API Routes with Full CRUD (json-api/src/routes/api.cr)

```crystal
require "json"
require "../helpers/json_response"
require "../models/note"

private def read_json_object(env : HTTP::Server::Context) : Hash(String, JSON::Any)?
  raw = env.params.raw_body
  return nil if raw.strip.empty?
  parsed = JSON.parse(raw)
  parsed.as_h?
rescue JSON::ParseException
  nil
end

private def note_id(env : HTTP::Server::Context) : Int64?
  env.params.url["id"]?.try(&.to_i64?)
end

private def string_field(h : Hash(String, JSON::Any), key : String) : String?
  h[key]?.try(&.as_s?)
end

get "/api/notes" do |env|
  list = Note.all.map(&.to_h)
  env.json({"notes" => list})
end

get "/api/notes/:id" do |env|
  id = note_id(env)
  unless id
    halt env.status(:bad_request).json({"error" => "invalid id"})
  end

  note = Note.find(id)
  if note
    env.json(note.to_h)
  else
    env.status(:not_found).json({"error" => "note not found"})
  end
end

post "/api/notes" do |env|
  obj = read_json_object(env)
  unless obj
    halt env.status(:bad_request).json({"error" => "expected JSON object body"})
  end

  title = string_field(obj, "title").try(&.strip) || ""
  if title.empty?
    halt env.status(:unprocessable_entity).json({"error" => "title is required"})
  end

  body = string_field(obj, "body").try(&.strip) || ""
  new_id = Note.create(title, body)
  note = Note.find(new_id)

  if note
    env.status(:created).json(note.to_h)
  else
    env.status(:internal_server_error).json({"error" => "failed to load created note"})
  end
end

delete "/api/notes/:id" do |env|
  id = note_id(env)
  unless id
    halt env.status(:bad_request).json({"error" => "invalid id"})
  end

  note = Note.find(id)
  unless note
    halt env.status(:not_found).json({"error" => "note not found"})
  end

  note.delete
  env.status(:no_content)
end
```

## Best Practices

- **Use Context Response Helpers:** Leverage `env.json` and `env.status(...)` for idiomatic, chainable response handling.
- **Consistent Error Format:** Always return a JSON object with an `error` key for failure states.
- **Safe Field Access:** Use `obj[key]?.try(&.as_s?)` or similar safe accessors for fields in parsed JSON hashes.
- **Input Validation:** Rigorously validate required fields and types before processing the request.
- **Status Symbols:** Use standard status symbols like `:ok`, `:created`, `:no_content`, `:bad_request`, `:unauthorized`, `:not_found`, `:unprocessable_entity`.

## When to Use

- When developing or refactoring API routes that return JSON.
- When handling JSON body parameters from client requests.
- When implementing standardized JSON error handling.
