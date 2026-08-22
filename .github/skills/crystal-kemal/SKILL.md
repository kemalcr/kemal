---
name: crystal-kemal
description: Use when building, reviewing, debugging, testing, securing, or deploying web applications and HTTP APIs with the Kemal framework for Crystal. Covers Kemal routing, params, context, routers, filters, middleware, ECR, WebSockets, SSE, uploads, configuration, testing, and production concerns.
license: MIT
---

# Kemal development

Use this skill for Kemal-specific work. Assume normal Crystal language knowledge and follow the Crystal documentation for language semantics that are not specific to Kemal.

## Core rules

- Prefer Kemal's own APIs and terminology over Ruby/Sinatra assumptions.
- Match parameters to the request encoding: `env.params.url`, `.query`, `.json`, `.body`, and `.files` are not interchangeable.
- Route definition order matters: the first matching route wins.
- Use `Kemal::Router` and namespaces to structure larger applications.
- Use filters for concise route-lifecycle behavior; use middleware for reusable handler-layer concerns and plugins.
- A middleware handler must call `call_next` only when processing should continue.
- Keep business logic out of ECR templates.
- Treat every request-derived value as untrusted until validated.
- Do not pass unchecked user-controlled paths to `send_file`.
- Configure production WebSocket origins explicitly when browser clients are expected; origin validation is not authentication.
- Add or update specs when route or middleware behavior changes.
- Prefer current Kemal repository APIs over patterns remembered from older versions.

## Quick start

```crystal
require "kemal"

get "/" do
  "Hello World!"
end

Kemal.run
```

Add Kemal to `shard.yml`:

```yaml
dependencies:
  kemal:
    github: kemalcr/kemal
```

Then:

```bash
shards install
crystal run src/my_app.cr
```

## Routing

Kemal supports the common HTTP verbs plus `QUERY`:

```crystal
get "/users"
post "/users"
put "/users/:id"
patch "/users/:id"
delete "/users/:id"
query "/search"
```

Routes are matched in definition order. Check broad/wildcard routes for shadowing before adding more specific routes later.

Dynamic route parameters:

```crystal
get "/users/:id" do |env|
  id = env.params.url["id"]?
  env.json({id: id})
end
```

Wildcard remainder:

```crystal
get "/files/*all" do |env|
  env.params.url["all"]?
end
```

For `QUERY` (RFC 10008, on Kemal master and not yet in a stable release), use the same Kemal parameter APIs appropriate to the request body. A QUERY request with a body and no `Content-Type` is rejected with 400 Bad Request according to Kemal's current behavior.

## Parameters

Query parameters:

```crystal
width = env.params.query["width"]?
```

JSON body (`Content-Type: application/json`):

```crystal
name = env.params.json["name"]?.as?(String)
```

Form/body parameters:

```crystal
name = env.params.body["name"]?.as?(String)
```

Repeated/bracketed form keys must be accessed exactly as sent, for example `env.params.body["likes[]"]?`.

Uploads are available through `env.params.files`.

## Request and response context

Prefer response helpers when they express the result clearly:

```crystal
get "/users" do |env|
  env.json({users: %w[alice bob]})
end

post "/users" do |env|
  env.status(:created).json({created: true})
end
```

Manual response control remains available through `env.response` for headers, status, and content type.

Use `halt` inside routes when route execution must stop:

```crystal
get "/admin" do |env|
  halt env.status(:forbidden).html("<h1>Forbidden</h1>")
end
```

Do not treat `halt` as generic middleware control flow.

## Modular routers

```crystal
api = Kemal::Router.new

api.namespace "/users" do
  get "/" do |env|
    env.json({users: %w[alice bob]})
  end
end

mount "/api/v1", api
```

Routers can contain routes, filters, WebSockets, SSE endpoints, and nested namespaces. Keep router-scoped behavior scoped unless global behavior is intentional.

## Filters and middleware

Common filters include `before_all`, verb-specific `before_*` and matching `after_*` filters, including `before_query` / `after_query` for QUERY routes.

Typical order:

```text
before_all -> before_<verb> -> route -> after_<verb> -> after_all
```

A `HEAD` request without its own route is served by the `GET` route, and it runs that route's filters as well as any registered for `HEAD`. `before_get` guards therefore apply to `HEAD`, and so do `Kemal::Handler` `only` / `exclude` rules scoped to `GET`.

Reusable cross-cutting behavior belongs in middleware:

```crystal
class CustomHandler < Kemal::Handler
  def call(env)
    # before
    call_next env
    # after, if appropriate
  end
end

# Preferred modern registration (Kemal 1.10+):
use CustomHandler.new

# Or configure on Kemal.config:
# Kemal.config.add_handler CustomHandler.new
```

Do not call `call_next` after intentionally short-circuiting the request.

## Views

Render ECR templates with `render` and use a second path for layouts. Layout content is available as `content`; `content_for` / `yield_content` can define named slots.

Keep application and authorization logic outside templates.

## Security-sensitive behavior

- Validate dynamic `send_file` paths using canonical containment inside an allowed root.
- Validate upload presence, size, type/extension as appropriate, and destination path before persistence.
- Use server-controlled upload names when client filenames could affect paths.
- Keep private uploads outside automatically served public directories.
- Set explicit request/multipart size limits appropriate to the application.
- Keep secrets outside source control.
- Avoid leaking stack traces, filesystem paths, database errors, tokens, or session secrets.
- Use HTTPS in production and configure security headers at a deliberate layer.
- Treat WebSocket origin checks as an additional browser boundary, not authentication/authorization.

## Testing

Use `spec-kemal` for application-level Kemal specs:

```yaml
development_dependencies:
  spec-kemal:
    github: kemalcr/spec-kemal
```

```crystal
require "spec-kemal"
require "../src/my_app"

describe "My App" do
  it "renders /" do
    get "/"
    response.body.should eq "Hello World!"
  end
end
```

Run:

```bash
KEMAL_ENV=test crystal spec
```

Test success and rejection paths, status codes, content types, parameter decoding, route ordering, middleware behavior, authorization, and upload/path validation where relevant.

## Load detailed references only when relevant

For more detail, read the smallest relevant reference file instead of loading everything:

- Routing, params, context, routers, views, filters, middleware, errors, static files: [`references/http-core.md`](references/http-core.md)
- Sessions, uploads, WebSockets, SSE, caching: [`references/realtime-state.md`](references/realtime-state.md)
- Limits, security, configuration, tests, builds, proxies, databases, checklist: [`references/operations.md`](references/operations.md)

## Verification checklist

Before considering Kemal work complete:

- [ ] Route ordering does not shadow expected endpoints.
- [ ] Each route uses the intended HTTP verb, including `QUERY` where applicable.
- [ ] URL/query/JSON/form/file params use the correct `env.params.*` source.
- [ ] Inputs are validated at trust boundaries.
- [ ] Status codes and content types are intentional.
- [ ] Router/filter/middleware scope is correct.
- [ ] Middleware continues with `call_next` only when intended.
- [ ] Dynamic file paths and uploads cannot escape allowed storage roots.
- [ ] WebSocket origin policy is explicit when needed and auth is handled separately.
- [ ] Request and multipart limits are intentional.
- [ ] Relevant `spec-kemal` tests pass.
- [ ] Production build and deployment behavior are verified for the target platform.

## Specialized domain skills

For targeted domain implementations with tested patterns from [`kemal-by-example`](https://github.com/sdogruyol/kemal-by-example), see the dedicated domain skills:

- **Core Routing & Handlers**: [`kemal-core`](../kemal-core/SKILL.md)
- **Real-Time WebSockets**: [`kemal-websocket`](../kemal-websocket/SKILL.md)
- **Server-Sent Events (SSE)**: [`kemal-sse`](../kemal-sse/SKILL.md)
- **JSON APIs & Helpers**: [`kemal-json`](../kemal-json/SKILL.md)
- **Middleware & HMAC**: [`kemal-middleware`](../kemal-middleware/SKILL.md)
- **File Uploads & Security**: [`kemal-upload`](../kemal-upload/SKILL.md)
- **Authentication & Sessions**: [`kemal-auth`](../kemal-auth/SKILL.md)
- **SQLite Database & Models**: [`kemal-database`](../kemal-database/SKILL.md)
- **OAuth2 Integration**: [`kemal-oauth`](../kemal-oauth/SKILL.md)
- **Crecto ORM**: [`kemal-orm`](../kemal-orm/SKILL.md)
- **Views & ECR Templates**: [`kemal-view`](../kemal-view/SKILL.md)

## Sources

Treat the current Kemal repository and official Kemal documentation as the source of truth. Use current APIs when this skill conflicts with newer project documentation.
