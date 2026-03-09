{% extends '_layout.swig' %}
{% block content %}
  <article class="post page-guestbook">
    <header class="post-header"><h1 class="post-title">{{ page.title || 'Guestbook' }}</h1></header>
    <div class="post-content">{{ page.content | safe }}</div>
    {% include '_partial/guestbook_cusdis.swig' %}
  </article>
{% endblock %}

<script>
document.addEventListener('DOMContentLoaded', function () {
  const wrap = document.getElementById('cusdis_thread');
  if (!wrap) return;

  function getIframe() { return wrap.querySelector('iframe'); }

  window.addEventListener('message', function (e) {
    try {
      const data = e.data || {};
      // Cusdis 的几种可能格式，尽量兼容
      const isCusdis = data.from === 'cusdis' || data.type === 'cusdis.resize' || data.type === 'resize';
      const height = data?.data?.height || data?.height;
      if (isCusdis && height) {
        const ifr = getIframe();
        if (ifr) {
          ifr.style.height = height + 'px';
          ifr.style.maxHeight = 'none';
          ifr.style.overflow = 'visible';
        }
      }
    } catch (_) {}
  });
});
</script>