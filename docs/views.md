# Views

You can use ECR to build views. Kemal serves a `render` macro to use built-in `ECR`
library.

## Writing Views

The ECR is actually ERB.

```
src/
  views/
    hello.ecr
```

Write `hello.ecr`
```erb
Hello <%= your_name %>
```

## Embedding View File

```crystal
get '/' do |env|
  your_name = "Kemal"
  render "views/hello.ecr"
end
```
