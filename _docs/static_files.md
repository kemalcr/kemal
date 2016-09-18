---
layout: doc
title: Static Files
---

Add your files to `public` directory and Kemal will serve these files immediately.

```
app/
  src/
    your_app.cr
  public/
    js/
      jquery.js
      your_app.js
    css/
      your_app.css
    index.html
```

Open index.html and add

```html
<html>
 <head>
   <script src="/js/jquery.js"></script>
   <script src="/js/your_app.js"></script>
   <link rel="stylesheet" href="/css/your_app.css"/>
 </head>
 <body>
   ...
 </body>
</html>
```

## Static File Options

### Disabling Static Files

By default `Kemal` serves static files from `public` folder. 
If you don't need static file serving at all(for example an API won't gonna need it) you can disable it like

```crystal
serve_static false
```

### Modifying Other Options

By default `Kemal` gzips most files, skipping only very small files, or those which don't benefit from gzipping.
If you are running `Kemal` behind a proxy, you may wish to disable this feature. `Kemal` is also able
to do basic directory listing. This feature is disabled by default. Both of these options are available by
passing a hash to `serve_static`

```crystal
serve_static({"gzip" => true, "dir_listing" => false})
```