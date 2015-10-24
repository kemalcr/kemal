# Kemal

[Sinatra](http://www.sinatrarb.com/) clone for [Crystal](http://www.crystal-lang.org).

Kemal is under heavy development and currently supports Crystal 0.9.0.

# Super Simple <3

```ruby
require "kemal"

get "/" do
  "Hello World!"
end
```

Go to *http://localhost:3000*

Check [samples](https://github.com/sdogruyol/kemal/tree/master/samples) for more.

# Installation

Add it to your ```shard.yml```

```yml
dependencies:
  kemal:
    github: sdogruyol/kemal
    branch: master
```

## Status

Basic `get`, `put`, `post` and `head` routes can be matched, and request parameters can be obtained.

## Thanks

Thanks to Manas for their awesome work on [Frank](https://github.com/manastech/frank).
