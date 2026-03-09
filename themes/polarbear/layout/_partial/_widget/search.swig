<div class="widget widget-search">
  <form id="sidebar-search-form" action="{{ url_for('/search/') }}" method="get"
        onsubmit="return this.q.value.trim().length > 0;">
    <div class="search-input-wrap">
      <input
        type="text"
        name="q"
        placeholder="Search…"
        autocomplete="off"
      />
      <button class="icon-btn" type="submit" aria-label="Search">
        <!-- 放大镜图标 (SVG) -->
        <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
          <circle cx="11" cy="11" r="7" fill="none" stroke="currentColor" stroke-width="2"></circle>
          <line x1="16.5" y1="16.5" x2="21" y2="21"
                stroke="currentColor" stroke-width="2" stroke-linecap="round"></line>
        </svg>
      </button>
    </div>
  </form>
</div>

<style>
.widget-search .search-input-wrap { position: relative; }
.widget-search input[name="q"] {
  width: 100%;
  box-sizing: border-box;
  padding: .6rem 2.25rem .6rem .8rem;
  border: 1px solid #ddd;
  border-radius: 9999px;
  font-size: 1rem;
}
.widget-search .icon-btn {
  position: absolute;
  right: .4rem;
  top: 50%;
  transform: translateY(-50%);
  border: 0;
  background: transparent;
  padding: .25rem;
  line-height: 0;
  color: inherit;
  cursor: pointer;
}
.widget-search .icon-btn:hover { opacity: .85; }
</style>

<script>
(function() {
  const form = document.getElementById('sidebar-search-form');
  if (!form) return;
  const input = form.querySelector('input[name="q"]');
  if (!input) return;

  // 每次页面显示（包括后退）时清空输入框
  window.addEventListener('pageshow', (e) => {
    const fromBFCache =
      (e.persisted === true) ||
      (performance && performance.getEntriesByType &&
        performance.getEntriesByType('navigation')[0] &&
        performance.getEntriesByType('navigation')[0].type === 'back_forward') ||
      (performance && performance.navigation && performance.navigation.type === 2);

    // 无论是普通加载还是从搜索页后退，都清空
    input.value = '';
  });

  // 提交后立刻清空一次（防止浏览器自动保留）
  form.addEventListener('submit', () => {
    setTimeout(() => { input.value = ''; }, 0);
  });
})();
</script>
