---
name: kemal-core
description: Core Kemal development (routing verbs, parameters, modular router, version gates, response helpers).
license: MIT
---

# Kemal Core Development

This skill provides expert guidance on using the Kemal web framework for Crystal, with version notes for when APIs landed.

## Version Notes

Everything in this skill works on current Kemal unless marked otherwise.

- HTTP `QUERY` method (RFC 10008) — `query`, `before_query`, `after_query`: since Kemal 1.13.0 (on 1.12.0 and earlier, use `post` or `get` with query parameters).
- `Kemal.config.max_ranges` (Range request bounds): since Kemal 1.13.0.
- Response helpers (`env.json`, `env.status`, `env.html`, `env.text`): since Kemal 1.10.
- `Kemal::Router`, `mount`, `namespace`: since Kemal 1.10.
- `Kemal.config.max_request_body_size`: since Kemal 1.9. `Kemal.config.shutdown_timeout`: since Kemal 1.10.1.

## Core Mandates

- **Routing:** Use top-level route methods (`get`, `post`, `put`, `patch`, `delete`, `options`) or modular routers (`Kemal::Router`).
- **HTTP QUERY Method (RFC 10008) — *[Kemal 1.13.0+]*:**
  - On Kemal 1.13.0+, use `query` for safe, read-only queries with complex request bodies (JSON or form-encoded):

  ```crystal
  # Kemal 1.13.0+:
  query "/search" do |env|
    q = env.params.json["q"]?.as?(String)
    halt env.status(:bad_request).json({error: "Query parameter 'q' required"}) unless q
    results = Product.search(q)
    env.json({results: results})
  end
  ```

  *Note*: A `QUERY` request carrying a body without a `Content-Type` header is rejected with `400 Bad Request`. On 1.12.0 and earlier, use `post` or query parameters via `get` instead.

- **Modular Routers (Kemal 1.10+):** Use `Kemal::Router.new` for namespaced routes, scoped middleware, and mounting under path prefixes:

  ```crystal
  api = Kemal::Router.new
  api.namespace "/users" do
    get "/" do |env|
      env.json({users: %w[alice bob]})
    end
    get "/:id" do |env|
      env.text "user #{env.params.url["id"]?}"
    end
  end

  mount "/api/v1", api
  ```

- **Parameters:** Match parameters to request encoding (they are not interchangeable):
  - URL parameters: `env.params.url["id"]` (raises on missing key) or `env.params.url["id"]?` (safe access)
  - Body parameters (`application/x-www-form-urlencoded` or multipart): `env.params.body["name"]?`
  - Query parameters (`?key=val`): `env.params.query["search"]?`
  - JSON parameters (`application/json`): `env.params.json["field"]?.as?(String)`
  - File parameters: `env.params.files["file"]`
  - Raw request body: `env.params.raw_body` (for multi-handler raw body access)

- **Response Helpers:** Use context response helpers (`env.json`, `env.status`, `env.html`, `env.text`, `halt`). For deep JSON API patterns and status helpers, refer to [`kemal-json`](../kemal-json/SKILL.md).

- **Rendering:** Use the `render` macro with view and optional layout paths (see [`kemal-view`](../kemal-view/SKILL.md)):

  ```crystal
  render "src/views/posts/index.ecr", "src/views/layouts/application.ecr"
  ```

- **Middleware Registration:** Use `use` (Kemal 1.10+) or `Kemal.config.add_handler` (see [`kemal-middleware`](../kemal-middleware/SKILL.md)):
  - Path-specific middleware: `use "/api", [CORSHandler.new, AuthHandler.new]`
  - Global middleware: `use MyHandler.new`

## Patterns from Source Code

### URL Parameter Access (Safe Pattern)

Always use the safe pattern for URL parameters to handle missing or invalid IDs:

```crystal
# Use the `?` accessor and `to_i64?` for IDs:
id = env.params.url["id"]?.try(&.to_i64?)
halt env.status(:bad_request).json({error: "Invalid ID"}) unless id
post = Post.find(id)
```

### Body Parameter Access & Raw Body

Always use safe access with `try` for body parameters:

```crystal
title = env.params.body["title"]?.try(&.strip) || ""
body = env.params.body["body"]?.try(&.strip) || ""

# Access raw request body across multiple handlers:
raw = env.params.raw_body
```

### Modular Router with Namespaces

Organize sub-systems cleanly using `Kemal::Router`:

```crystal
require "kemal"

admin_router = Kemal::Router.new

admin_router.namespace "/posts" do
  get "/" do |env|
    posts = Post.all
    env.json(posts.map(&.to_h))
  end

  get "/:id" do |env|
    id = env.params.url["id"]?.try(&.to_i64?)
    post = id ? Post.find(id) : nil
    if post
      env.json(post.to_h)
    else
      halt env.status(:not_found).json({error: "Post not found"})
    end
  end

  # HTTP QUERY (Kemal 1.13.0+):
  query "/search" do |env|
    term = env.params.json["term"]?.as?(String)
    halt env.status(:bad_request).json({error: "Search term required"}) unless term
    posts = Post.search(term)
    env.json(posts.map(&.to_h))
  end
end

mount "/admin", admin_router
```

## Best Practices

- **Separation of Concerns:** Keep route logic minimal. Delegate complex operations to models or services.
- **Static Files:** Kemal serves files from the `public` directory by default. Configure this via `Kemal.config.public_folder`.
- **Request Body Size Limits (Kemal 1.9+):** Limit maximum request body size to prevent DoS:
  ```crystal
  Kemal.config.max_request_body_size = 50 * 1024 * 1024 # 50 MB
  ```
- **Range Request Bounds (Kemal 1.13.0+):** Kemal bounds HTTP `Range` request parts (default 16) to mitigate CVE-2011-3192 resource exhaustion:
  ```crystal
  # Kemal 1.13.0+:
  Kemal.config.max_ranges = 16 # set to 0 to ignore Range headers entirely
  ```
- **Graceful Shutdown (Kemal 1.10.1+):** Configure shutdown timeout so in-flight requests finish cleanly before exit:
  ```crystal
  Kemal.config.shutdown_timeout = 10.seconds
  ```

## When to Use

- When creating or modifying routes in a Kemal application.
- When organizing modular route namespaces with `Kemal::Router` (Kemal 1.10+).
- When handling incoming request parameters (URL, body, query, JSON, files, raw body).
- When implementing search/filter endpoints (using `get`/`post` on 1.12.0 and earlier, or `query` on 1.13.0+).
- When returning JSON, HTML, or plain text responses.
- When configuring global runtime settings and security bounds for Kemal.
