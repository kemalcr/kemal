---
layout: doc
title: Serving Static Files
---

## Static Files

Kemal has built-in support for serving your static files. You need to put your static files under your ```/public``` directory.

E.g: A static file like ```/public/index.html``` will be served with the matching route ```/index.html```.

## Production / Development Mode

By default Kemal starts in ```development```mode and logs to STDOUT.

You can use ```production``` mode to redirect the output to a file. By default Kemal logs the output to ```kemal.log```.

You can start Kemal in production mode by:

```./your_app -e production```
