{% extends "_layout.swig" %}

{% block title %}
  {% if page.title %}{{ page.title }}{% else %}Journal{% endif %} - {{ config.title }}
{% endblock %}

{% block content %}
<section class="journal-wrap">
  <header class="journal-header">
    <h1>{% if page.title %}{{ page.title }}{% else %}Journal{% endif %}</h1>
  </header>

  {# ===== 收集 journal entries，并顺便收集 jtags（用于筛选按钮）===== #}
  {% set journal_count = 0 %}
  {% set allTagStr = '' %}

  {% for p in site.pages %}
    {% if p.layout == 'journal_entry' %}
      {% set journal_count = journal_count + 1 %}
      {% if p.jtags and p.jtags.length %}
        {% for t in p.jtags %}
          {% set allTagStr = allTagStr + t + ' ' %}
        {% endfor %}
      {% endif %}
    {% endif %}
  {% endfor %}

  {# ===== Tag 筛选条（从 jtags 去重：用“字符串包含”做简单去重）===== #}
  <div class="journal-filter">
    <button class="journal-filter-btn is-active" type="button" data-tag="__all">All</button>

    {% set seen = ' ' %}
    {% for p in site.pages %}
      {% if p.layout == 'journal_entry' %}
        {% if p.jtags and p.jtags.length %}
          {% for t in p.jtags %}
            {# 简单去重：seen 字符串里没有 " t " 才输出 #}
            {% set key = ' ' + t + ' ' %}
            {% if seen.indexOf(key) < 0 %}
              {% set seen = seen + t + ' ' %}
              <button class="journal-filter-btn" type="button" data-tag="{{ t }}">#{{ t }}</button>
            {% endif %}
          {% endfor %}
        {% endif %}
      {% endif %}
    {% endfor %}
  </div>

  {# ===== 渲染 journal entries（不在 swig 里排序，继续用 JS 排序）===== #}
  <div class="journal-list" id="journalList">
    {% for p in site.pages %}
      {% if p.layout == 'journal_entry' %}

        {# 拼 data-tags（来自 jtags） #}
        {% set tagStr = '' %}
        {% if p.jtags and p.jtags.length %}
          {% for t in p.jtags %}
            {% set tagStr = tagStr + t + ' ' %}
          {% endfor %}
        {% endif %}

        <article class="journal-item" data-tags="{{ tagStr | trim }}" data-date="{{ p.date.toISOString() }}">
          <div class="journal-meta">
            <time datetime="{{ p.date.toISOString() }}">{{ date(p.date, "YYYY-MM-DD HH:mm") }}</time>

            {% if p.jtags and p.jtags.length %}
              <span class="journal-tags">
                {% for t in p.jtags %}
                  <span class="journal-tag">#{{ t }}</span>
                {% endfor %}
              </span>
            {% endif %}
          </div>

          <div class="journal-post-title">
            {% if p.title %}{{ p.title }}{% endif %}
          </div>

          <div class="journal-content journal-content--collapsed">
            {{ p.content }}
          </div>

          <button class="journal-more" type="button" aria-expanded="false">More</button>
        </article>

      {% endif %}
    {% endfor %}

    {% if journal_count == 0 %}
      <p class="journal-empty">还没有广播。</p>
    {% endif %}
  </div>
</section>

<script>
(function () {
  var list = document.getElementById('journalList');
  if (!list) return;

  // 1) 强制按时间逆序排序（最新在前）
  var nodes = Array.prototype.slice.call(list.querySelectorAll('.journal-item'));
  nodes.sort(function (a, b) {
    var da = new Date(a.getAttribute('data-date')).getTime();
    var db = new Date(b.getAttribute('data-date')).getTime();
    return db - da;
  });
  nodes.forEach(function (n) { list.appendChild(n); });

  // 2) Tag 筛选
  var btns = document.querySelectorAll('.journal-filter-btn');
  function setActive(btn) {
    Array.prototype.forEach.call(btns, function (b) { b.classList.remove('is-active'); });
    btn.classList.add('is-active');
  }

  function filter(tag) {
    nodes.forEach(function (it) {
      var tags = (it.getAttribute('data-tags') || '').split(/\s+/).filter(Boolean);
      if (tag === '__all') { it.style.display = ''; return; }
      it.style.display = tags.indexOf(tag) >= 0 ? '' : 'none';
    });
  }

  Array.prototype.forEach.call(btns, function (btn) {
    btn.addEventListener('click', function () {
      var tag = btn.getAttribute('data-tag');
      setActive(btn);
      filter(tag);
    });
  });

  // 3) 展开/收起：默认折叠 4 行
  list.addEventListener('click', function (e) {
    var btn = e.target.closest('.journal-more');
    if (!btn) return;

    var item = btn.closest('.journal-item');
    if (!item) return;

    var content = item.querySelector('.journal-content');
    if (!content) return;

    var expanded = content.classList.toggle('journal-content--collapsed') === false;
    btn.setAttribute('aria-expanded', expanded ? 'true' : 'false');
    btn.textContent = expanded ? 'Less' : 'More';
  });
})();
</script>
{% endblock %}