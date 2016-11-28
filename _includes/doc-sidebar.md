<div class="Sidebar">
  <div class="h3 Sidebar_title">Guide</div>
  <nav class="Sidebar_nav">
    {% assign sorted_pages = (site.docs | sort: 'order') %}
    {% for post in sorted_pages %}
      <a href="{{ post.url | prepend: site.baseurl }}">{{ post.title }}</a>
    {% endfor %}
  </nav>
</div>
