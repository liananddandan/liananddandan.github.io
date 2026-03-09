// source/js/search.js
// Minimal client-side search for Hexo + polarbear (Fuse.js required)

// 读取 ?q=
const getQueryQ = () => (new URLSearchParams(window.location.search).get("q") || "").trim();

// 英文/中文两套参数
const fuseOptionsEnglish = {
    keys: ["title", "content", "tags", "categories"],
    includeScore: true,
    includeMatches: true,
    isCaseSensitive: false,
    ignoreLocation: false,   // 英文：顺序敏感
    findAllMatches: false,
    minMatchCharLength: 2,   // 英文至少2字符
    threshold: 0.3,          // 严格但对完整词友好
    distance: 50
};
const fuseOptionsChinese = {
    keys: ["title", "content", "tags", "categories"],
    includeScore: true,
    includeMatches: true,
    isCaseSensitive: false,
    ignoreLocation: true,    // 中文：任意位置
    findAllMatches: true,
    minMatchCharLength: 1,   // 单字可匹配
    threshold: 0.5,          // 稍宽松
    distance: 100
};
// 严格字面匹配开关（开启后默认走严格模式，不再用 Fuse）
const STRICT_LITERAL = true;
// 是否区分大小写（严格匹配时用）
const CASE_SENSITIVE = false;

const literalIncludes = (haystack, needle) => {
    if (!haystack || !needle) return false;
    if (CASE_SENSITIVE) return haystack.indexOf(needle) >= 0;
    return haystack.toLowerCase().indexOf(needle.toLowerCase()) >= 0;
};

(function () {
    const log = (...args) => console.log("[search]", ...args);
    const byId = (id) => document.getElementById(id);
    const inputEl = byId("search-input");
    const resultsEl = byId("search-results");
    const SEARCH_URL = (typeof SEARCH_JSON_URL !== "undefined" && SEARCH_JSON_URL) || "/search.json";

    if (!inputEl || !resultsEl) {
        console.error("[search] missing #search-input or #search-results");
        return;
    }

    const stripHTML = (s) => (s || "").replace(/<[^>]*>/g, "");
    const escapeHTML = (s) =>
        (s || "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

    // 是否包含中日汉字（CJK）/ 是否含 ASCII 词
    const hasCJKChars = (txt) => /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]/.test(txt || "");
    const hasAsciiWord = (txt) => /[A-Za-z0-9]/.test(txt || "");

    // 防抖
    const debounce = (fn, ms) => {
        let t = null;
        return (...args) => { clearTimeout(t); t = setTimeout(() => fn.apply(null, args), ms); };
    };

    // 渲染：全部
    const renderAll = (posts) => {
        resultsEl.innerHTML = posts.map((p) => {
            const title = escapeHTML(p.title || "(untitled)");
            const preview = escapeHTML((p.content || "").slice(0, 100)) + ((p.content || "").length > 100 ? " …" : "");
            const href = p.url || "#";
            return `<p class="search-item">
        <a href="${href}" class="search-title"><strong>${title}</strong></a><br>
        <small class="search-snippet">${preview}</small>
      </p>`;
        }).join("");
    };

    let fuse = null;
    let posts = [];
    let lastResults = [];
    let lastQueryLower = ""; // 用于兜底高亮

    // 渲染：搜索结果（含高亮/就近摘要 + 兜底朴素高亮）
    const renderResults = (matches) => {
        if (!matches.length) { resultsEl.innerHTML = `<p>No results.</p>`; return; }

        resultsEl.innerHTML = matches.map(({ item, matches }) => {
            let title = escapeHTML(item.title || "(untitled)");
            let snippet = escapeHTML((item.content || "").slice(0, 100)) + ((item.content || "").length > 100 ? " …" : "");
            const href = item.url || "#";

            // 标题高亮（Fuse indices）
            const tMatch = (matches || []).find((m) => m.key === "title" && m.indices?.length);
            if (tMatch) {
                const [ts, te] = tMatch.indices[0];
                const raw = item.title || "";
                title = `${escapeHTML(raw.slice(0, ts))}<mark>${escapeHTML(raw.slice(ts, te + 1))}</mark>${escapeHTML(raw.slice(te + 1))}`;
            }

            // 正文就近摘要 + 高亮（Fuse indices）
            const cMatch = (matches || []).find((m) => m.key === "content" && m.indices?.length);
            if (cMatch) {
                const [cs, ce] = cMatch.indices[0];
                const raw = item.content || "";
                const start = Math.max(0, cs - 40);
                const end = Math.min(raw.length, ce + 40);
                const pre = escapeHTML(raw.slice(start, cs));
                const hit = escapeHTML(raw.slice(cs, ce + 1));
                const post = escapeHTML(raw.slice(ce + 1, end));
                snippet = `${start > 0 ? "… " : ""}${pre}<mark>${hit}</mark>${post}${end < raw.length ? " …" : ""}`;
            }

            // 兜底：当 Fuse 未提供 matches（例如来自 includes/AND 或命中 tags/categories）时，用当前查询做朴素高亮
            if (!tMatch && lastQueryLower) {
                const ttl = (item.title || "").toLowerCase();
                const ti = ttl.indexOf(lastQueryLower);
                if (ti >= 0) {
                    const raw = item.title || "";
                    title = `${escapeHTML(raw.slice(0, ti))}<mark>${escapeHTML(raw.slice(ti, ti + lastQueryLower.length))}</mark>${escapeHTML(raw.slice(ti + lastQueryLower.length))}`;
                }
            }
            if (!cMatch && lastQueryLower) {
                const raw = item.content || "";
                const cl = raw.toLowerCase();
                const ci = cl.indexOf(lastQueryLower);
                if (ci >= 0) {
                    const start = Math.max(0, ci - 40);
                    const end = Math.min(raw.length, ci + lastQueryLower.length + 40);
                    const pre = escapeHTML(raw.slice(start, ci));
                    const hit = escapeHTML(raw.slice(ci, ci + lastQueryLower.length));
                    const post = escapeHTML(raw.slice(ci + lastQueryLower.length, end));
                    snippet = `${start > 0 ? "… " : ""}${pre}<mark>${hit}</mark>${post}${end < raw.length ? " …" : ""}`;
                }
            }

            return `<p class="search-item">
        <a href="${href}" class="search-title">${title}</a><br>
        <small class="search-snippet">${snippet}</small>
      </p>`;
        }).join("");
    };

    async function init() {
        try {
            log("script loaded");
            const resp = await fetch(SEARCH_URL, { cache: "no-store" });
            const raw = await resp.json();

            // 兼容不同生成器字段
            const list = Array.isArray(raw) ? raw : raw.posts || [];
            posts = list.map((p) => ({
                title: p.title || "",
                content: stripHTML(p.content || p.text || ""),
                url: p.url || p.path || "",
                tags: (p.tags || []).map(t => typeof t === "string" ? t : (t?.name || "")),
                categories: (p.categories || []).map(c => typeof c === "string" ? c : (c?.name || "")),
            }));

            log(`loaded ${posts.length} posts`);

            // 根据 URL 初始关键词选择模式并建索引
            const initialQ = getQueryQ();
            const initialIsEnglish = initialQ ? !hasCJKChars(initialQ) : true;
            fuse = new Fuse(posts, initialIsEnglish ? fuseOptionsEnglish : fuseOptionsChinese);

            // 先渲染全部
            renderAll(posts);

            // 如有 ?q=，自动搜索
            if (initialQ) {
                inputEl.value = initialQ;
                await runSearch(initialQ, /*fromInit*/ true);
            }

            // 输入事件：URL 同步 + 检索
            inputEl.addEventListener("input", debounce(async () => {
                const q = inputEl.value.trim();

                // 地址栏同步
                const u = new URL(window.location.href);
                if (q) u.searchParams.set("q", q); else u.searchParams.delete("q");
                history.replaceState(null, "", u.toString());

                if (!q) { renderAll(posts); lastResults = []; return; }

                await runSearch(q, /*fromInit*/ false);
            }, 120));

            // Enter：仅在有结果时跳转首条
            inputEl.addEventListener("keydown", (e) => {
                if (e.key === "Enter") {
                    e.preventDefault();
                    //   const q = inputEl.value.trim();
                    //   if (q && Array.isArray(lastResults) && lastResults.length > 0) {
                    //     const href = lastResults[0].item?.url;
                    //     if (href) window.location.href = href;
                    //   }
                }
            });
        } catch (err) {
            console.error("[search] failed:", err);
            resultsEl.innerHTML = `<p style="color:#c00;">Search init failed.</p>`;
        }
    }

    // 统一搜索：混合 AND 兜底 → 按语言 Fuse → includes 兜底
    // 统一搜索：严格字面匹配（开启 STRICT_LITERAL 时）
    // 命中条件：title 或 content 含有完整的查询子串；不分词、不改顺序。
    // 朴素高亮由 renderResults 的兜底逻辑完成（基于 lastQueryLower）。
    async function runSearch(q, fromInit) {
        // 记录当前查询（用于兜底高亮）
        lastQueryLower = CASE_SENSITIVE ? (q || "") : (q || "").toLowerCase();

        if (STRICT_LITERAL) {
            // 严格模式：只做字面子串匹配
            const hits = posts.filter(p =>
                literalIncludes(p.title || "", q) || literalIncludes(p.content || "", q)
            ).map(p => ({ item: p })); // 适配 renderResults 的数据结构

            lastResults = hits;
            renderResults(hits);
            return;
        }

        // —— 如果以后想恢复 Fuse，就把上面的 STRICT_LITERAL=false 即可，下面保留你的 Fuse 流程 ——
        const isEnglishNow = !/[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]/.test(q);
        fuse = new Fuse(posts, isEnglishNow ? fuseOptionsEnglish : fuseOptionsChinese);
        let res = fuse.search(q);

        if (!res.length) {
            // includes 兜底（保留你之前的逻辑）
            const qlc = q.toLowerCase();
            const fallback = posts.filter(p =>
                (p.title || "").toLowerCase().includes(qlc) ||
                (p.content || "").toLowerCase().includes(qlc)
            ).map(p => ({ item: p }));
            if (fallback.length) {
                lastResults = fallback;
                renderResults(fallback);
                return;
            }
        }
        lastResults = res;
        renderResults(res);
    }


    // DOM Ready
    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }
})();
