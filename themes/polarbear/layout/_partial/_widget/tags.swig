{% if theme.widget.Tags %}
  <section id="tags" class="widget-area widget_tags">
    <h3 class="widget-title">Tags</h3>

    <ul class="tag-list">
      {% for tag in site.tags %}
        <li class="tag-list-item">
          <a class="tag-list-link" href="{{ url_for(tag.path) }}">
            {{ tag.name }}
          </a>
          <span class="tag-list-count">{{ tag.length }}</span>
        </li>
      {% endfor %}
    </ul>

  </section>
{% endif %}