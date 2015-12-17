<img src="https://avatars3.githubusercontent.com/u/15321198?v=3&s=200" width="100" height="100" />
# Kemal [![Build Status](https://travis-ci.org/sdogruyol/kemal.svg?branch=master)](https://travis-ci.org/sdogruyol/kemal)

[![Join the chat at https://gitter.im/sdogruyol/kemal](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/sdogruyol/kemal?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

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
crystal run src/kemal_sample.cr
```
Go to *http://localhost:3000*

Check [documentation](https://github.com/sdogruyol/kemal/tree/master/docs) or [samples](https://github.com/sdogruyol/kemal/tree/master/samples) for more.

# Super Fast <3

Numbers speak louder than words.

| Framework | Request Per Second  | Avg. Response Time |
| :------------ |:---------------:| -----:|
| Kemal (Production)    | 64986 | 170μs  |
| Sinatra (Thin)     | 2274        |   43.82ms |


These results were achieved with ```wrk``` on a Macbook Pro Late 2013. (**2Ghz i7 8GB Ram OS X Yosemite**)

# Features

- Support all REST verbs
- Websocket support
- Request/Response context, easy parameter handling
- Middlewares
- Built-in JSON support
- Built-in static file serving
- Built-in view templating via ecr

# Documentation

You can read the documentation under [docs](https://github.com/sdogruyol/kemal/tree/master/docs) folder.

## Thanks

Thanks to Manas for their awesome work on [Frank](https://github.com/manastech/frank).
