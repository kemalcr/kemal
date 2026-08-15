# Kemal HTTP core reference

## Method override

HTML forms directly support GET and POST. When PUT/PATCH/DELETE-style forms are required, add `Kemal::OverrideMethodHandler::INSTANCE` explicitly and use the `_method` form parameter. Do not assume the handler is enabled by default.

## Context storage

Store request-scoped values with `env.set`; retrieve them with `env.get` or `env.get?`. Register custom types with `add_context_storage_type(Type)` before use. Context storage is request-local, not persistent process state.

## ECR

```crystal
get "/:name" do |env|
  name = env.params.url["name"]
  render "src/views/hello.ecr"
end
```

Layouts:

```crystal
render "src/views/page.ecr", "src/views/layouts/layout.ecr"
```

The layout renders the child result through `<%= content %>`. Use `content_for` and `yield_content` for named slots.

## Filters

Filters are route-lifecycle hooks. Multiple filters for the same verb/path run in definition order. Global wildcard filters can still affect router-scoped routes.

Plugins and reusable addons should prefer middleware over injecting broad filters.

## Middleware

Global/path-scoped middleware can be registered with `use`; custom handlers inherit from `Kemal::Handler`.

Be explicit about whether a handler is global, path-scoped, `only`, or `exclude` constrained. A short-circuiting handler must not continue into the remainder of the chain.

## Custom logger

Subclass `Kemal::BaseLogHandler` and assign `Kemal.config.logger`. Avoid logging credentials, tokens, sensitive headers, session secrets, or raw sensitive request bodies.

## Redirects and errors

Use `env.redirect` for route redirects. Clear authentication/session state first when logout semantics require it.

Status handlers use `error 404 do ... end`; exception handlers use `error MyError do ... end`. Definition order affects exception-handler resolution, so check broad handlers before narrower ones.

Production error responses must not expose stack traces, internal paths, secrets, or database details.

## `send_file`

For dynamic paths:

1. Define an allowed root.
2. Canonicalize/normalize the requested candidate.
3. Verify the resolved path remains inside the allowed root.
4. Reject traversal and unexpected absolute paths.
5. Apply authorization independently of path containment.

Literal substring checks such as only searching for `../` are not a complete containment boundary.

## Static files

Kemal serves files from its public directory automatically. Configure `Kemal.config.public_folder` and `Kemal.config.serve_static` as needed. Avoid redundant routes that shadow static-file behavior and keep directory listing disabled unless intentionally required.
