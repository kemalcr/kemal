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
	env.redirect "/login" # redirect to /login page
end
```

## Custom Public Folder

Kemal mounts `./public` root path of the project as the default public asset folder. You can change this by using `public_folder`.

```ruby
  public_folder "path/to/your/folder"
```
