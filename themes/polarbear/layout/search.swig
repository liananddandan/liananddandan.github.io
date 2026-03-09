{% extends 'page.swig' %}

{% block content %}
<div class="search-page" style="max-width:800px;margin:0 auto;">
  <h1>Search</h1>
  <input id="search-input" type="text" placeholder="Search..." style="width:100%;padding:0.6rem;font-size:1rem;">
  <div id="search-results" style="margin-top:1rem;"></div>
</div>

<!-- 引入 Fuse.js（CDN 版本，先简化） -->
<script src="https://cdn.jsdelivr.net/npm/fuse.js/dist/fuse.min.js"></script>

<!-- 注入 search.json 的路径（供前端脚本使用） -->
<script>
  const SEARCH_JSON_URL = "{{ url_for('/search.json') }}";
</script>

<!-- 你的前端脚本（稍后放到 source/js/search.js） -->
<script src="{{ url_for('/js/search.js') }}"></script>
{% endblock %}