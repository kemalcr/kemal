---
name: kemal-view
description: Rendering ECR templates and layouts with Kemal.
---

# Kemal View Rendering

This skill provides expert guidance on rendering HTML templates using ECR (Embedded Crystal) in Kemal, strictly following patterns from `src/kemal-by-example/`.

## Compatibility Matrix

| Feature | Kemal 1.12.0 (Release) | Kemal Master (Unreleased / Next) |
| :--- | :--- | :--- |
| `render` Macro (View only) | Supported | Supported |
| `render` Macro with Layout (`view, layout`) | Supported | Supported |
| Layout Yield (`<%= content %>`) | Supported | Supported |
| Local Variable Bindings in ECR Scope | Supported | Supported |

## Core Mandates

- **Rendering:** Use `render "path/to/view.ecr"` for simple rendering.
- **Layouts:** Use `render "path/to/view.ecr", "path/to/layout.ecr"` for layout support.
- **Paths:** Always use relative paths from the project root (e.g., `src/views/index.ecr`).
- **Data Passing:** Local variables in the route block are directly accessible within ECR templates.

## Patterns from Source Code

### Basic Route with View Rendering

```crystal
# blog/src/routes/posts.cr
get "/posts" do
  posts = Post.all
  render "src/views/posts/index.ecr", "src/views/layouts/application.ecr"
end
```

### Route with Local Variables for Views

```crystal
# ecommerce/src/routes/auth.cr
get "/signup" do |env|
  current_user = Ecommerce::Auth.current_user(env)
  cart_count = if (user = current_user) && (uid = user.id)
                 CartItem.total_quantity_for_user(uid)
               else
                 0_i64
               end
  error_message = nil

  render "src/views/auth/signup.ecr", "src/views/layouts/application.ecr"
end
```

### Edit Route with Conditional Rendering

```crystal
# blog/src/routes/posts.cr
get "/posts/:id/edit" do |env|
  id = env.params.url["id"]?.try(&.to_i64?)
  post = id ? Post.find(id) : nil

  if post
    render "src/views/posts/edit.ecr", "src/views/layouts/application.ecr"
  else
    env.response.status = :not_found
    "Post not found"
  end
end
```

### Layout Template Structure

Typical layout file at `src/views/layouts/application.ecr`:

```html
<!DOCTYPE html>
<html>
<head>
  <title>My App</title>
</head>
<body>
  <nav>
    <!-- Navigation content -->
  </nav>

  <main>
    <%= content %>
  </main>

  <footer>
    <!-- Footer content -->
  </footer>
</body>
</html>
```

### View Template Example

Typical view file at `src/views/posts/index.ecr`:

```html
<h1>Posts</h1>

<% posts.each do |post| %>
  <article>
    <h2><%= post.title %></h2>
    <p><%= post.body %></p>
    <a href="/posts/<%= post.id %>/edit">Edit</a>
  </article>
<% end %>

<a href="/posts/new">New Post</a>
```

### Error Rendering with Local Variables

```crystal
# ecommerce/src/routes/auth.cr
post "/login" do |env|
  email = env.params.body["email"]?.try(&.strip) || ""
  password = env.params.body["password"]?.try(&.strip) || ""
  user = User.authenticate(email, password)

  if user
    Ecommerce::Auth.sign_in(env, user)
    env.redirect "/products"
  else
    current_user = nil
    cart_count = 0_i64
    error_message = "Invalid email or password."
    env.response.status = :unprocessable_entity
    render "src/views/auth/login.ecr", "src/views/layouts/application.ecr"
  end
end
```

## Best Practices

- **Layout Structure:** Use `<%= content %>` in layout files to render the view content.
- **Partials:** Use `render "path/to/_partial.ecr"` for reusable UI components (not shown in examples but standard practice).
- **ECR Directives:** Prefer `<%= ... %>` for output and `<% ... %>` for logic/control flow.
- **Sanitization:** Be mindful of XSS when outputting user-provided data. Use `HTML.escape` where necessary.
- **Local Variables:** Pass data to views by defining local variables in the route block before calling `render`.
- **Error Handling:** Handle missing resources (404) by checking models before rendering, or set appropriate status codes.

## When to Use

- When creating or modifying HTML views in a Kemal application.
- When setting up or changing the main application layout.
- When organizing view files and partials.
