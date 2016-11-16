---
layout: doc
title: Restful Web Services
order: 2
---

You can handle HTTP methods as easy as writing method names and the route with a code block. Kemal will handle all the hard work.

```ruby
get "/" do
.. show something ..
end

post "/" do
.. create something ..
end

put "/" do
.. replace something ..
end

patch "/" do
.. modify something ..
end

delete "/" do
.. annihilate something ..
end
```
