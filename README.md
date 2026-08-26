[![Kemal](https://avatars3.githubusercontent.com/u/15321198?v=3&s=200)](http://kemalcr.com)

# Kemal - Fast, Effective, Simple Web Framework for Crystal

Build web applications and APIs with minimal code. 3.8k+ ⭐, 5M+ downloads since 2015.

[![Stars](https://img.shields.io/github/stars/kemalcr/kemal?style=flat-square&label=%20&color=gold)](https://github.com/kemalcr/kemal)
[![CI](https://github.com/kemalcr/kemal/actions/workflows/ci.yml/badge.svg?style=flat-square)](https://github.com/kemalcr/kemal/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/kemalcr/kemal?style=flat-square)](https://github.com/kemalcr/kemal/releases)
![Downloads](https://img.shields.io/badge/Downloads-5M%2B-gold?style=flat-square)
![Crystal](https://img.shields.io/badge/Crystal-1.19+-%23000?style=flat-square&logo=crystal)
[![License](https://img.shields.io/github/license/kemalcr/kemal?style=flat-square)](LICENSE)
![Built with Crystal](https://img.shields.io/badge/Built%20with-Crystal-776791?style=flat-square&logo=crystal)

---

## Quick Start

1. **Create a new project**
   ```bash
   crystal init app my-app
   cd my-app
   ```

2. **Add Kemal to `shard.yml`**
   ```yaml
   dependencies:
     kemal:
       github: kemalcr/kemal
   ```

3. **Write your app** - replace `src/my-app.cr` with:
   ```crystal
   require "kemal"

   get "/" do
     "Hello World!"
   end

   get "/api" do |env|
     env.response.content_type = "application/json"
     {status: "ok"}.to_json
   end

   Kemal.run
   ```

4. **Install dependencies and run**
   ```bash
   shards install
   crystal run src/my-app.cr
   ```

Visit http://localhost:3000 - done in under a minute. 🚀

---

## Why Kemal?

| Problem | Solution |
|---------|----------|
| "I want C-level performance with Ruby-like syntax" | Crystal + Kemal - fast by default |
| "I need WebSocket support out of the box" | Built-in, no extra gems |
| "Building a JSON API" | Native JSON handling, minimal boilerplate |
| "I want a framework that stays out of my way" | No forced ORM, no magic, just Crystal |

---

## Key Features

- 🚀 **High-performance by default** - Built on Crystal with a thin abstraction layer
- 🌐 **Full REST & HTTP support** - All HTTP verbs with a straightforward routing DSL
- 🔌 **WebSocket & real-time** - First-class WebSocket support
- 📦 **JSON-first APIs** - Native JSON handling
- 🗄️ **Static assets** - Serve files efficiently from the same application
- 📝 **Template engine** - Built-in ECR template engine
- 🔒 **Composable middleware** - Logging, auth, rate limiting, metrics
- 🎯 **Ergonomic request/response** - Simple params, headers, cookies via context
- 🍪 **Session management** - Production-ready via kemal-session

---

## Performance

Kemal is built on Crystal. It compiles to native code and starts instantly.

| Test | Results |
|------|---------|
| **JSON serialization** (100 conn) | ~50,000 req/sec |
| **Hello World** (100 conn) | ~85,000 req/sec |
| **Static file serving** | ~40,000 req/sec |
| **Memory per request** | ~0.5 KB |
| **Binary size** | ~2 MB (with dependencies) |

No JVM, no Node, no Ruby VM. Just a native binary.

---

## How Kemal compares

| Feature | Kemal | Sinatra | Flask | Express |
|---------|:-----:|:-------:|:-----:|:-------:|
| **Performance** (req/sec) | ~85K | ~5K | ~3K | ~15K |
| **WebSocket** built-in | ✅ | - | - | - |
| **Single binary deploy** | ✅ | - | - | - |
| **JSON handling** | Native | Gem | Extension | Native |
| **Type safety** | ✅ | - | - | - |
| **Concurrency** | Fibers | Threads | Threads | Async |

---

## Philosophy

Kemal aims to be a simple, fast and reliable foundation for building production-grade web applications and APIs in Crystal.

- **Simple core, powerful building blocks** - The core is intentionally simple. Most power comes from Crystal and middleware, not hidden magic.
- **Performance as a baseline** - Crystal's native speed means high performance is the default. Kemal keeps abstractions thin.
- **Minimal assumptions, maximum flexibility** - No forced ORM, template engine, or project layout. Choose your own tools.
- **Batteries within reason** - Ships with essentials (routing, middleware, templates, static files) while keeping advanced concerns in separate shards.

---

## Learning Resources

- 📚 [Official Documentation](http://kemalcr.com)
- 💻 [Example Applications](https://github.com/kemalcr/kemal/tree/master/examples)
- 🚀 [Kemal Guide](http://kemalcr.com/guide/)
- 💻 [Kemal By Example](https://github.com/sdogruyol/kemal-by-example)
- 💬 [Community Chat](https://discord.gg/prSVAZJEpz)

---

## FAQ

**Is Kemal production ready?**

Yes. Kemal has been used in production since 2015 with 5M+ downloads.

**Does Kemal support WebSocket?**

Yes, built-in. No extra dependencies needed.

**Can I build a REST API with Kemal?**

Yes. JSON handling is built-in. Return hashes or JSON directly from routes.

**Does Kemal support the HTTP QUERY method?**

Yes. QUERY ([RFC 10008](https://www.rfc-editor.org/rfc/rfc10008)) is a safe, idempotent method that carries the query in the request body instead of the URL:

```crystal
query "/search" do |env|
  q = env.params.json["q"]? # or env.params.body for form-encoded queries
  search_products(q).to_json
end
```

`before_query` / `after_query` filters and `Kemal::Router#query` work like every other verb. A QUERY request that has a body but no `Content-Type` header is rejected with `400` per the RFC.

**Does Kemal work with any ORM?**

Yes. You can use any Crystal ORM or database library. No forced dependencies.

**How is Kemal different from Sinatra / Flask / Express?**

Kemal compiles to a native binary with Crystal. You get C-like performance, type safety, and single-binary deployment. Sinatra and Flask are interpreted. Express runs on Node's event loop.

---

## Sponsors

If Kemal helps you or your company, consider [sponsoring](https://github.com/sponsors/sdogruyol). Your support helps me maintain Kemal and build the Crystal ecosystem full time.

[![Sponsor](https://img.shields.io/badge/Sponsor-30363D?style=flat-square&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/sdogruyol)

### Corporate

<p align="center">
  <a href="https://marsus.com">
    <img src="https://github.com/marsus-com.png?size=280" width="140" alt="Marsus"><br>
    Marsus
  </a>
</p>

### Crystal Champions

<p align="center">
  <a href="https://github.com/f">
    <img src="https://github.com/f.png?size=160" width="80" alt="Fatih Kadir Akın"><br>
    Fatih Kadir Akın
  </a>
</p>

### Backers

<table align="center">
  <tr>
    <td align="center">
      <a href="https://github.com/pyrsmk">
        <img src="https://github.com/pyrsmk.png?size=120" width="56" alt="Aurélien Delogu"><br>
        Aurélien Delogu
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/JadeKharats">
        <img src="https://github.com/JadeKharats.png?size=120" width="56" alt="David YOTEAU"><br>
        David YOTEAU
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/mvatansever">
        <img src="https://github.com/mvatansever.png?size=120" width="56" alt="Mesut Vatansever"><br>
        Mesut Vatansever
      </a>
    </td>
  </tr>
</table>

### Supporters

<p align="center">
  <a href="https://github.com/treagod"><img src="https://github.com/treagod.png?size=80" width="40" alt="Marvin Ahlgrimm"></a>
  <a href="https://github.com/hahwul"><img src="https://github.com/hahwul.png?size=80" width="40" alt="hahwul"></a>
  <a href="https://github.com/jwoertink"><img src="https://github.com/jwoertink.png?size=80" width="40" alt="Jeremy Woertink"></a>
  <a href="https://github.com/laktosterror"><img src="https://github.com/laktosterror.png?size=80" width="40" alt="laktosterror"></a>
  <a href="https://github.com/luislavena"><img src="https://github.com/luislavena.png?size=80" width="40" alt="Luis Lavena"></a>
  <a href="https://github.com/nbrandaleone"><img src="https://github.com/nbrandaleone.png?size=80" width="40" alt="Nick Brandaleone"></a>
  <a href="https://github.com/tarikcayir"><img src="https://github.com/tarikcayir.png?size=80" width="40" alt="Tarık Çayır"></a>
</p>

---

## Contributing

We love contributions! Please read our [Contributing Guide](CONTRIBUTING.md).

## Security

To report a security vulnerability, please see our [Security Policy](SECURITY.md).

---

## Acknowledgments

Special thanks to Manas for their work on [Frank](https://github.com/manastech/frank).

---

## License

MIT