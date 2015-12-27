---
layout: default
---

<div class="doc-sidebar">

  <h1 class="doc-heading">Documents</h1>

  <ul class="doc-list">
    {% for post in site.docs %}
      <li>
        <h2>
          <a class="doc-link" href="{{ post.url | prepend: site.baseurl }}">{{ post.title }}</a>
        </h2>
      </li>
    {% endfor %}
  </ul>

</div>
