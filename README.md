![Kemal](https://avatars3.githubusercontent.com/u/15321198?v=3&s=200)

# Kemal

Lightning Fast, Super Simple web framework for [Crystal](http://www.crystal-lang.org).
Inspired by [Sinatra](http://www.sinatrarb.com/)

Kemal is under heavy development and currently supports Crystal 0.9.0.

# Super Simple <3

```ruby
require "kemal"

get "/" do
  "Hello World!"
end
```

Build and run!

```
crystal build --release src/kemal_sample.cr
./kemal_sample
```
Go to *http://localhost:3000*

Check [samples](https://github.com/sdogruyol/kemal/tree/master/samples) for more.

# Installation

Add it to your ```shard.yml```

```yml
dependencies:
  kemal:
    github: kemalcr/kemal
    branch: master
```

## Status

Basic `get`, `put`, `post`, `patch`, `delete` and `head` routes can be matched, and request parameters can be obtained.

## Thanks

Thanks to Manas for their awesome work on [Frank](https://github.com/manastech/frank).
