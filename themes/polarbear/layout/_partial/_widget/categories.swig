{% if theme.widget.Categories %}
  <section id="tags" class="widget-area widget_categories">
    <h3 class="widget-title">Categories</h3>

    <ul class="category-list">
      {% for category in site.categories %}
        {% if category.name != 'journal' %}
          <li class="category-list-item">
            <a class="category-list-link" href="{{ url_for(category.path) }}">
              {{ category.name }}
            </a>
            <span class="category-list-count">{{ category.length }}</span>
          </li>
        {% endif %}
      {% endfor %}
    </ul>
  </section>
{% endif %}