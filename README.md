[![Kemal](https://avatars3.githubusercontent.com/u/15321198?v=3&s=200)](http://kemalcr.com)

# Kemal

Kemal is the Fast, Effective, Simple Web Framework for Crystal. It's perfect for building Web Applications and APIs with minimal code.

[![CI](https://github.com/kemalcr/kemal/actions/workflows/ci.yml/badge.svg)](https://github.com/kemalcr/kemal/actions/workflows/ci.yml)

## Why Kemal?

- 🚀 **Lightning Fast**: Built on Crystal, known for C-like performance
- 💡 **Super Simple**: Minimal code needed to get started
- 🛠 **Feature Rich**: Everything you need for modern web development
- 🔧 **Flexible**: Easy to extend with middleware support

## Quick Start

1. First, make sure you have [Crystal installed](https://crystal-lang.org/install/).

2. Add Kemal to your project's `shard.yml`:

```yaml
dependencies:
  kemal:
    github: kemalcr/kemal
```

3. Create your first Kemal app:

```crystal
require "kemal"

# Basic route - responds to GET "http://localhost:3000/"
get "/" do
  "Hello World!"
end

# JSON API example
get "/api/status" do |env|
  env.response.content_type = "application/json"
  {"status": "ok"}.to_json
end

# WebSocket support
ws "/chat" do |socket|
  socket.send "Hello from Kemal WebSocket!"
end

Kemal.run
```

4. Run your application:

```bash
crystal run src/your_app.cr
```

5. Visit [http://localhost:3000](http://localhost:3000) - That's it! 🎉

## Key Features

- ✅ **Full REST Support**: Handle all HTTP verbs (GET, POST, PUT, DELETE, etc.)
- 🔌 **WebSocket Support**: Real-time bidirectional communication
- 📦 **Built-in JSON Support**: Native JSON handling
- 🗄️ **Static File Serving**: Serve your static assets easily
- 📝 **Template Support**: Built-in ECR template engine
- 🔒 **Middleware System**: Add functionality with middleware
- 🎯 **Request/Response Context**: Easy parameter and request handling
- 🍪 **Session Management**: Easy session handling with [kemal-session](https://github.com/kemalcr/kemal-session)

## Philosophy

Kemal aims to be a simple, fast and reliable foundation for building production-grade web applications and APIs in Crystal.

- **Simple core, powerful building blocks**: The core is intentionally simple and easy to reason about. Most power comes from Crystal itself and from middleware, not from hidden magic.
- **Performance as a baseline, not a feature**: Crystal's native speed means high performance is the default. Kemal keeps abstractions thin so you stay close to the metal when you need to.
- **Minimal assumptions, maximum flexibility**: Kemal does not force a specific ORM, template engine, or project layout. You are free to choose the tools that fit your application and your team.
- **Batteries within reason**: Kemal ships with the essentials (routing, middleware, templates, static files, request/response helpers) while keeping advanced concerns in separate shards you can opt into as your app grows.

Kemal is designed to feel familiar if you come from popular web frameworks, while embracing Crystal's strengths and keeping your application code straightforward, maintainable, and ready for production.

## Learning Resources

- 📚 [Official Documentation](http://kemalcr.com)
- 💻 [Example Applications](https://github.com/kemalcr/kemal/tree/master/examples)
- 🚀 [Kemal Guide](http://kemalcr.com/guide/)
- 💬 [Community Chat](https://discord.gg/prSVAZJEpz)


## Contributing

We love contributions! Please read our [Contributing Guide](CONTRIBUTING.md) to get started.

## Acknowledgments

Special thanks to Manas for their work on [Frank](https://github.com/manastech/frank).

## License

Kemal is released under the MIT License.
