---
layout: doc
title: Utilities
---

## Browser Redirect

Just like other things in `kemal`, browser redirection is super simple as well. Use `environment` variable in defined route's corresponding block and call `redirect` on it.

```ruby
  # Redirect browser
  get "/logout" do |env|
	# important stuff like clearing session etc.
	redirect "/login" # redirect to /login page
  end
```
_Make sure to receive `env` as param in defined route's block or you might end-up having compile-time errors._
