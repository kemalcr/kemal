
[![Kemal](https://avatars3.githubusercontent.com/u/15321198?v=3&s=200)](http://kemalcr.com)

# Kemal

Lightning Fast, Super Simple web framework.

[![Build Status](https://travis-ci.org/kemalcr/kemal.svg?branch=master)](https://travis-ci.org/kemalcr/kemal)
[![Join the chat at https://gitter.im/sdogruyol/kemal](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/sdogruyol/kemal?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![OpenCollective](https://opencollective.com/kemal/backers/badge.svg)](#backers) 
[![OpenCollective](https://opencollective.com/kemal/sponsors/badge.svg)](#sponsors)


# Super Simple ️

```ruby
require "kemal"

# Matches GET "http://host:port/"
get "/" do
  "Hello World!"
end

# Creates a WebSocket handler.
# Matches "ws://host:port/socket"
ws "/socket" do |socket|
  socket.send "Hello from Kemal!"
end

Kemal.run
```

Start your application!

```
crystal src/kemal_sample.cr
```
Go to *http://localhost:3000*

Check [documentation](http://kemalcr.com) or [samples](https://github.com/kemalcr/kemal/tree/master/samples) for more.

# Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  kemal:
    github: kemalcr/kemal
```

# Features

- Support all REST verbs
- Websocket support
- Request/Response context, easy parameter handling
- Middlewares
- Built-in JSON support
- Built-in static file serving
- Built-in view templating via [Kilt](https://github.com/jeromegn/kilt)

# Documentation

You can read the documentation at the official site [kemalcr.com](http://kemalcr.com)

## Thanks

Thanks to Manas for their awesome work on [Frank](https://github.com/manastech/frank).

## Backers

Support us with a monthly donation and help us continue our activities. [[Become a backer](https://opencollective.com/kemal#backer)]

<a href="https://opencollective.com/kemal/backer/0/website" target="_blank"><img src="https://opencollective.com/kemal/backer/0/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/1/website" target="_blank"><img src="https://opencollective.com/kemal/backer/1/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/2/website" target="_blank"><img src="https://opencollective.com/kemal/backer/2/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/3/website" target="_blank"><img src="https://opencollective.com/kemal/backer/3/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/4/website" target="_blank"><img src="https://opencollective.com/kemal/backer/4/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/5/website" target="_blank"><img src="https://opencollective.com/kemal/backer/5/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/6/website" target="_blank"><img src="https://opencollective.com/kemal/backer/6/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/7/website" target="_blank"><img src="https://opencollective.com/kemal/backer/7/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/8/website" target="_blank"><img src="https://opencollective.com/kemal/backer/8/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/9/website" target="_blank"><img src="https://opencollective.com/kemal/backer/9/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/10/website" target="_blank"><img src="https://opencollective.com/kemal/backer/10/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/11/website" target="_blank"><img src="https://opencollective.com/kemal/backer/11/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/12/website" target="_blank"><img src="https://opencollective.com/kemal/backer/12/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/13/website" target="_blank"><img src="https://opencollective.com/kemal/backer/13/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/14/website" target="_blank"><img src="https://opencollective.com/kemal/backer/14/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/15/website" target="_blank"><img src="https://opencollective.com/kemal/backer/15/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/16/website" target="_blank"><img src="https://opencollective.com/kemal/backer/16/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/17/website" target="_blank"><img src="https://opencollective.com/kemal/backer/17/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/18/website" target="_blank"><img src="https://opencollective.com/kemal/backer/18/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/19/website" target="_blank"><img src="https://opencollective.com/kemal/backer/19/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/20/website" target="_blank"><img src="https://opencollective.com/kemal/backer/20/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/21/website" target="_blank"><img src="https://opencollective.com/kemal/backer/21/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/22/website" target="_blank"><img src="https://opencollective.com/kemal/backer/22/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/23/website" target="_blank"><img src="https://opencollective.com/kemal/backer/23/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/24/website" target="_blank"><img src="https://opencollective.com/kemal/backer/24/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/25/website" target="_blank"><img src="https://opencollective.com/kemal/backer/25/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/26/website" target="_blank"><img src="https://opencollective.com/kemal/backer/26/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/27/website" target="_blank"><img src="https://opencollective.com/kemal/backer/27/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/28/website" target="_blank"><img src="https://opencollective.com/kemal/backer/28/avatar.svg"></a>
<a href="https://opencollective.com/kemal/backer/29/website" target="_blank"><img src="https://opencollective.com/kemal/backer/29/avatar.svg"></a>

## Sponsors

Become a sponsor and get your logo on our README on Github with a link to your site. [[Become a sponsor](https://opencollective.com/kemal#sponsor)]

<a href="https://opencollective.com/kemal/sponsor/0/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/1/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/2/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/3/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/4/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/5/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/6/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/7/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/8/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/9/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/9/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/10/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/10/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/11/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/11/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/12/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/12/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/13/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/13/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/14/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/14/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/15/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/15/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/16/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/16/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/17/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/17/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/18/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/18/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/19/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/19/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/20/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/20/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/21/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/21/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/22/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/22/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/23/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/23/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/24/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/24/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/25/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/25/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/26/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/26/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/27/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/27/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/28/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/28/avatar.svg"></a>
<a href="https://opencollective.com/kemal/sponsor/29/website" target="_blank"><img src="https://opencollective.com/kemal/sponsor/29/avatar.svg"></a>
