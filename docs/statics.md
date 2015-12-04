# Statics

Add your files to `public` directory and Kemal will serve these files immediately.

```
app/
  src/
    awesome_web_project.cr
  public/
    js/
      jquery.js
      awesome_web_project.js
    css/
      awesome_web_project.css
    index.html
```

Open index.html and add

```html
<html>
 <head>
   <script src="/js/jquery.js"></script>
   <script src="/js/awesome_web_project.js"></script>
   <link rel="stylesheet" href="/css/awesome_web_project.css"/>
 </head>
 <body>
   ...
 </body>
</html>
```
