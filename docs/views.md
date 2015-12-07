# Views

You can use ECR to build views. Kemal serves a `render` macro to use Crystal's built-in `ECR`
library.

## Embedding View File

```crystal
get '/' do |env|
  your_name = "Kemal"
  render "views/hello.ecr"
end
```

## Writing Views

ECR is pretty similar ERB(from Ruby). As you can see you can easily access the block variables in your view. In this
example `your_name` is available for use in the view.

```
src/
  views/
    hello.ecr
```

Write `hello.ecr`
```erb
Hello <%= your_name %>
```
