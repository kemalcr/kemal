<div class="doc-sidebar">

  <h1 class="doc-heading">Guide</h1>

  <ul class="doc-list">

    {% assign sorted_pages = (site.docs | sort: 'order') %}
    {% for post in sorted_pages %}
      <li>
        <h2>
          <a class="doc-link" href="{{ post.url | prepend: site.baseurl }}">{{ post.title }}</a>
        </h2>
      </li>
    {% endfor %}
  </ul>
</div>
