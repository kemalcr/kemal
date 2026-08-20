---
name: kemal-middleware
description: Creating and using custom middleware in Kemal using modern `use` keyword and handler classes.
---

# Kemal Middleware & Handlers

This skill provides expert guidance on creating and using custom middleware in Kemal, leveraging modern `use` registration and filter macros, strictly following patterns from `src/kemal-by-example/webhook-inbox/`.

## Compatibility Matrix

| Feature | Kemal 1.12.0 (Release) | Kemal Master (Unreleased / Next) |
| :--- | :--- | :--- |
| `use` Keyword Registration | Supported (1.10+) | Supported |
| Path-Scoped `use "/api", [handlers]` | Supported (1.10+) | Supported |
| `Kemal::Handler` Inheritance & `call_next` | Supported | Supported |
| `only` / `exclude` Filtering with `*` & Globs | Supported (1.12.0+) | Supported |
| Auth Middleware Scope Fix (Prefix matching) | Partial | Supported (strict prefix check) |

## Core Mandates

- **Middleware Registration (`use` Keyword in Kemal 1.10+):** Prefer `use` for clean global or path-scoped middleware registration:

  ```crystal
  # Path-scoped middleware (applies only to /api routes)
  use "/api", [CORSHandler.new, AuthHandler.new]

  # Global middleware (applies to all routes)
  use CustomHandler.new
  ```

- **Configuration-based Registration:** Alternatively, use `Kemal.config.add_handler(CustomHandler.new)`. (The bare top-level `add_handler` is deprecated in favor of `use` and `Kemal.config.add_handler`).

- **Handlers:** Create custom middleware by inheriting from `Kemal::Handler`:

  ```crystal
  class MyHandler < Kemal::Handler
    def call(context)
      # Execution prior to next handler
      call_next(context)
      # Execution after next handler returns
    end
  end
  ```

- **Selective Filtering in Handlers:** Use `only` or `exclude` macros to restrict execution within the handler class. Supports specific verbs, all verbs (`"*"`), and path prefix globs (`"/*"`):

  ```crystal
  class MyHandler < Kemal::Handler
    # Matches all HTTP methods on /admin and sub-paths
    only %w[/admin/*], "*"

    def call(context)
      return call_next(context) unless only_match?(context)
      # Custom logic
      call_next(context)
    end
  end
  ```

- **Legacy Registration (`add_handler`):** `add_handler MyHandler.new` remains supported for backward compatibility.

- **Specialized Handlers (HMAC):** For HMAC signatures, `require "kemal-hmac"` and inherit from `Kemal::Hmac::Handler`:

  ```crystal
  class InboxHmacHandler < Kemal::Hmac::Handler
    only %w[/hooks/inbox], "POST"

    def call(context)
      return call_next(context) unless only_match?(context)
      super
    end
  end
  ```

## Patterns from Source Code

### HMAC Handler (webhook-inbox/src/middleware/inbox_hmac_handler.cr)

```crystal
require "kemal-hmac"

# Protects only `POST /hooks/inbox` with kemal-hmac.
class WebhookInbox::InboxHmacHandler < Kemal::Hmac::Handler
  only %w[/hooks/inbox], "POST"

  def call(context)
    return call_next(context) unless only_match?(context)
    super
  end
end
```

### Main Application Setup (webhook-inbox/src/webhook_inbox.cr)

```crystal
require "kemal"
require "kemal-hmac"
require "db"
require "sqlite3"

require "./config/app"
require "./config/database"
require "./config/schema"
require "./helpers/headers_json"
require "./middleware/inbox_hmac_handler"
require "./models/webhook_event"
require "./routes/home"
require "./routes/inbox"
require "./routes/events"

# Configure HMAC handler with client/secret mapping and use keyword
client = WebhookInbox.webhook_client
use WebhookInbox::InboxHmacHandler.new({client => [WebhookInbox.webhook_secret]})

WebhookInbox::Schema.setup
Kemal.run
```

## Best Practices

- **Use Keyword:** Prefer `use "/path", Handler.new` for path-scoped middleware instead of checking path conditions inside route blocks.
- **Minimalist Design:** Keep handlers focused on a single responsibility (e.g., CORS, logging, authorization).
- **Execution Order:** Order middleware intentionally (e.g., authentication handlers must run before route handlers that depend on auth context).
- **HMAC Setup:** For `Kemal::Hmac::Handler`, pass key/secret maps as `{ "client_id" => ["secret_key"] }`.

## When to Use

- When implementing cross-cutting concerns (authentication, CORS, security headers, logging).
- When protecting specific API routes using HMAC or token authorization.
- When organizing global or path-scoped request processing stacks.
