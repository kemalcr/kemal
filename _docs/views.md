---
layout: doc
title: Using Dynamic Views
---

You can use ERB-like built-in [ECR](http://crystal-lang.org/api/ECR.html) to render dynamic views.

```ruby
get '/:name' do |env|
  name = env.params.url["name"]
  render "src/views/hello.ecr"
end
```

And you should have an `hello.ecr` view. It will have the same context as the method.

```erb
Hello <%= name %>
```

## Using Layouts

You can use **layouts** in Kemal. You should pass a second argument.

```ruby
get '/:name' do
  render "src/views/subview.ecr", "src/views/layouts/layout.ecr"
end
```

And you should use `content` variable (like `yield` in Rails) in layout file.

```erb
<html>
<head>
  <title><%= $title %></title>
</head>
<body>
  <%= content %>
</body>
</html>
```

## Using Common Paths

Since Crystal does not allow using variables in macro literals, you need to generate
another *helper macro* to make the code easier to read and write.

```ruby
macro my_renderer(filename)
  render "my/app/view/base/path/#{{{filename}}}.ecr", "my/app/view/base/path/layouts/layout.ecr"
end
```

And now you can use your new renderer.

```ruby
get '/:name' do
  my_renderer "subview"
end
```
