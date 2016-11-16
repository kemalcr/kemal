---
layout: doc
title: "Error Handling"
order: 8
---

Error handlers run within the same context as routes and before filters which means you get all the power of those.

## 404 Not Found

When a Kemal::Exceptions::NotFound exception is raised, or the response’s status code is 404, the *error 404* handler is invoked:

You can customize the built-in *error 404* handler like below.

```ruby
error 404 do
  "This is a customized 404 page."
end
```

## Install other error handlers for status codes

Just like *error 404* handler you can install custom error handlers for different status codes.

```ruby
error 403 do
  "Access Forbidden!"
end

get "/" do |env|
  env.response.status_code = 403
end
```
