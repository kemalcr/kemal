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

### content_for and yield_content

`content_for` is a set of helpers that allows you to capture
blocks inside views to be rendered later during the request. The most
common use is to populate different parts of your layout from your view.

The currently supported engines are: ecr and slang.

#### Usage

You call `content_for`, generally from a view, to capture a block of markup
giving it an identifier:

```erb
# index.ecr
 <% content_for "some_key" do %>
  <chunk of="html">...</chunk>
<% end %>
Then, you call +yield_content+ with that identifier, generally from a
layout, to render the captured block:
```

```erb
 # layout.ecr
 <%= yield_content "some_key" %>
```

##### And How Is This Useful?

For example, some of your views might need a few javascript tags and
stylesheets, but you don't want to force this files in all your pages.
Then you can put `<%= yield_content :scripts_and_styles %>` on your
layout, inside the `<head>` tag, and each view can call `content_for`
setting the appropriate set of tags that should be added to the layout.

## Using Common Paths

Since Crystal does not allow using variables in macro literals, you need to generate
another *helper macro* to make the code easier to read and write.

{% raw %}
```
macro my_renderer(filename)
  render "my/app/view/base/path/#{{{filename}}}.ecr", "my/app/view/base/path/layouts/layout.ecr"
end
```
{% endraw %}

And now you can use your new renderer.

```ruby
get '/:name' do
  my_renderer "subview"
end
```
