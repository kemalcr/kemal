---
name: kemal-middleware
description: Creating and using custom middleware in Kemal using modern `use` keyword and handler classes.
license: MIT
---

# Kemal Middleware & Handlers

This skill provides expert guidance on creating and using custom middleware in Kemal, leveraging modern `use` registration and filter macros, strictly following patterns from [`kemal-by-example/webhook-inbox`](https://github.com/sdogruyol/kemal-by-example/tree/master/webhook-inbox).

## Version Notes

- `use` registration (global and path-scoped): since Kemal 1.10.
- `only` / `exclude` with a single method and exact paths: all supported versions.
- `only` / `exclude` with `"*"` methods and `"/*"` path globs: since Kemal 1.13.0 — do **not** use the glob syntax on 1.12.0 or earlier, where it matches every path (see the warning below).
- `HEAD` fallback route-scoped dispatch: since Kemal 1.13.0. On Kemal 1.12.0 and earlier, `HEAD` requests falling back to `GET` routes bypassed `GET`-scoped filters (`before_get`) and `GET`-scoped `only` / `exclude` middleware because dispatch checked the literal request method (`HEAD`) rather than the serving route method, creating an authentication bypass risk ([GHSA-jf9q-62h3-924j](https://github.com/kemalcr/kemal/security/advisories/GHSA-jf9q-62h3-924j)). Kemal 1.13.0+ evaluates both the request method and the serving route's effective method.
- `Kemal::Router` filters registered with trailing `/*` match path subtrees: since Kemal 1.13.0 (on 1.12.0 and earlier, trailing `*` was treated as a literal path segment and silently failed to register/match routes).

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

- **Selective Filtering in Handlers:** Use `only` or `exclude` macros to restrict execution within the handler class. On Kemal 1.12.0 they support a single HTTP method and exact paths only:

  ```crystal
  class MyHandler < Kemal::Handler
    only %w[/admin], "POST"

    def call(context)
      return call_next(context) unless only_match?(context)
      # Custom logic
      call_next(context)
    end
  end
  ```

  On Kemal 1.13.0+, `"*"` matches all methods and paths ending in `"/*"` match a prefix:

  ```crystal
  # Kemal 1.13.0+:
  class MyHandler < Kemal::Handler
    # Matches all HTTP methods on /admin and sub-paths
    only %w[/admin/*], "*"
    # ...
  end
  ```

  **WARNING:** Do not use `"*"` or `"/*"` globs on Kemal 1.12.0. The 1.12.0 route matcher treats `*` as a radix glob, so a rule like `only %w[/admin/*], "*"` matches **every path on every method** — an auth handler scoped this way locks the whole site. For middleware that should cover an entire path subtree on any version, prefer `use "/admin", MyHandler.new` instead.

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
