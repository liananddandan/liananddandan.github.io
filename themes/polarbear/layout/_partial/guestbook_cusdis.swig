<div id="guestbook" class="guestbook">
  <div id="cusdis_thread"
       data-host="https://cusdis.com"
       data-app-id="1075ca01-bbf1-40d5-9c6a-04aa0c887861"
       data-page-id="{{ page.permalink || url_for(page.path) }}"
       data-page-url="{{ config.url | default('') }}{{ url_for(page.path) }}"
       data-page-title="{{ page.title | default('Guestbook') }}">
  </div>
  <script async defer src="https://cusdis.com/js/cusdis.es.js"></script>
</div>