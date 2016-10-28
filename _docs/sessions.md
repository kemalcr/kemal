---
layout: doc
title: Sessions
---

Kemal's default session is in-memory only and holds simple **String** values only.
The client-side cookie stores a random ID.

Kemal handlers can access the session like so:

```ruby
get("/") do |env|
  env.session["abc"] = "xyz"
  uid = env.session["user_id"]?
end
```

Note that only String values are allowed.

Sessions are pruned hourly after 48 hours of inactivity.

## Changing the Session Cookie Name

By default the session cookie on the client is named `kemal_session`. To change the name, do:

```ruby
Kemal.config.session["name"] = "your_session_name"
```
