# Views

You can use ERB-like built-in **ECR** views to render files.

```crystal
get '/:name' do
  render "views/hello.ecr"
end
```

And you should have an `hello.ecr` view. It will have the same context as the method.

```erb
Hello <%= env.params["name"] %>
```
