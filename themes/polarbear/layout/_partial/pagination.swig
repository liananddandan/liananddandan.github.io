{% if not is_post() %}
<div class="pagination-wrapper">
  <nav class="pagination">
    {% if page.prev %}
      <a class="prev" href="{{ url_for(page.prev_link) }}">
        <i class="iconfont icon-left"></i>
        <span class="prev-text">{{ __('posts.prev') }}</span>
      </a>
    {% endif %}
    {% if page.next %}
      <a class="next" href="{{ url_for(page.next_link) }}">
        <span class="next-text">{{ __('posts.next') }}</span>
        <i class="iconfont icon-right"></i>
      </a>
    {% endif %}
  </nav>

  {# —— 1 先确定 total（集合总篇数）—— #}
  {% set total = 0 %}

  {# 标签页：根据当前 tag 统计 #}
  {% if page.tag %}
    {% for t in site.tags %}
      {% if t.name == page.tag %}
        {% set total = t.posts.length %}
      {% endif %}
    {% endfor %}

  {# 分类页：根据当前 category 统计 #}
  {% elseif page.category %}
    {% for c in site.categories %}
      {% if c.name == page.category %}
        {% set total = c.posts.length %}
      {% endif %}
    {% endfor %}

  {# 其它（首页/归档总览等）：用全站总数 #}
  {% else %}
    {% set total = site.posts.length %}
  {% endif %}

  {# —— 2 确定 per（每页数量，按页面类型读对应生成器配置，最后兜底全局）—— #}
  {% set per = 10 %}
  {% if page.tag and config.tag_generator and config.tag_generator.per_page %}
    {% set per = config.tag_generator.per_page %}
  {% else %}
    {% if page.category and config.category_generator and config.category_generator.per_page %}
      {% set per = config.category_generator.per_page %}
    {% else %}
      {% if config.index_generator and config.index_generator.per_page %}
        {% set per = config.index_generator.per_page %}
      {% else %}
        {% if config.per_page %}
          {% set per = config.per_page %}
        {% endif %}
      {% endif %}
    {% endif %}
  {% endif %}

  {# —— 3 计算当前页区间（按理论区间，最后一页封顶）—— #}
  {% set base = page.current %}
  {% set base = base - 1 %}
  {% set base = base * per %}
  {% set start = base + 1 %}
  {% set end = start + per - 1 %}
  {% if end > total %}{% set end = total %}{% endif %}

  <div class="pagination-info">
    <strong>{{ start }}</strong> - <strong>{{ end }}</strong> / <strong>{{ total }}</strong>
  </div>
</div>
{% else %}
  <nav class="post-nav">
    {% if page.prev.path %}
      <a class="prev" href="{{ url_for(page.prev.path) }}">
        <i class="iconfont icon-left"></i>
        <span class="prev-text nav-default">{{ page.prev.title }}</span>
        <span class="prev-text nav-mobile">{{ __('posts.prev_post') }}</span>
      </a>
    {% endif %}
    {% if page.next.path %}
      <a class="next" href="{{ url_for(page.next.path) }}">
        <span class="next-text nav-default">{{ page.next.title }}</span>
        <span class="prev-text nav-mobile">{{ __('posts.next_post') }}</span>
        <i class="iconfont icon-right"></i>
      </a>
    {% endif %}
  </nav>
{% endif %}