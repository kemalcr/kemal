---
layout: doc
title: Sessions
order: 11
---

Kemal's default session is in-memory only and can hold values of the following types: `String | Int64 | Float64 | Bool`.
The client-side cookie stores a random ID.

Kemal handlers can access the session like so:

```ruby
get("/") do |env|
  env.session["abc"] = "xyz"
  uid = env.session["user_id"]?.as(Int32)
end
```

By default, sessions are pruned hourly after 48 hours of inactivity. This can be configured:

```ruby
Kemal.config.session["expire_time"] = 24.hours
```

## Changing the Session Cookie Name

By default the session cookie on the client is named `kemal_session`. To change the name, do:

```ruby
Kemal.config.session["name"] = "your_session_name"
```
