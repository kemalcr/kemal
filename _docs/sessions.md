---
layout: doc
title: Sessions
order: 11
---

Kemal supports Sessions with [kemal-session](https://github.com/kemalcr/kemal-session).

`kemal-session` has a generic API to multiple storage engines. The default storage engine is `MemoryEngine` which stores the sessions in process memory.
It's ***only recommended*** to use `MemoryEngine` for development and test purposes. 

Please check [kemal-session][https://github.com/kemalcr/kemal-session] for usage and compatible storage engines.
