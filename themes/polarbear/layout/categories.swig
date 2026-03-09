{% extends "_layout.swig" %}

{% block title %} {{ __('menu.categories') }} - {{ config.title }} {% endblock %}

{% block content %}
  <div class="categories">
    <div class="categories-title">
      {{ _p('counter.categories', site.categories.length) }}
    </div>

    <div class="categories-tags">
      {% for category in site.categories.toArray() %}
        <a class="category-link" href="{{ url_for(category.path) }}">
          {{ category.name }}
        </a>
      {% endfor %}
    </div>
  </div>
{% endblock %}