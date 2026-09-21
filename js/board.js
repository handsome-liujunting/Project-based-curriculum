/* =========================================================
   V3.5 增补 —— 留言板（零依赖）

   和 js/feedback.js 是一对，但方向正好相反：
     · feedback.js → 只写不读，内容私密，只有站点作者能在后台看到
     · board.js    → 又写又读，内容公开，写在下面每个人都看得到

   做什么：
     1) 打开页面就 GET 一次，把最近 30 条留言渲染成卡片贴到墙上
     2) 访客填写 → POST 到 Supabase 的 messages 表 → 成功后重新拉一遍
     3) 提交中禁用按钮；失败保留已写内容；成功才提示"贴上去了"
     4) 后台还没配置时，不假装成功：改成"复制 + 邮件"兜底通道
     5) 渲染一律用 createElement + textContent 逐字插入，
        **绝不拼 HTML 字符串** —— 否则有人留一句 <script> 就是 XSS

   为什么不用 supabase-js：与 feedback.js 保持一致，只用 fetch 打 PostgREST。
   ========================================================= */

(function () {
  "use strict";

  var cfg = window.FEEDBACK_CONFIG || {};

  /* 兜底通道用的邮箱：和「联系」区块里的邮箱保持一致 */
  var MAIL = "2909114517@qq.com";

  /* 墙上最多挂多少条（数据库里不删，只是页面不一次全拉） */
  var LIMIT = 30;

  var listEl    = document.getElementById("bdList");
  var stateEl   = document.getElementById("bdState");
  var form      = document.getElementById("bdForm");
  var nameEl    = document.getElementById("bdName");
  var msgEl     = document.getElementById("bdMessage");
  var countEl   = document.getElementById("bdCount");
  var submitBtn = document.getElementById("bdSubmit");
  var statusEl  = document.getElementById("bdStatus");
  var fallbackEl= document.getElementById("bdFallback");
  var copyBtn   = document.getElementById("bdCopy");
  var moreEl    = document.getElementById("bdMore");

  /* 缺少必要节点就直接报错退出。
     （不静默返回：上一版数字分身就是静默失败，整块功能死了却没有任何提示，
       所以 tools\verify_v35.ps1 里专门加了一条 id 契约检查。） */
  if (!listEl || !stateEl || !form || !nameEl || !msgEl || !submitBtn || !statusEl) {
    console.error("[board] 留言板缺少必要的 DOM 节点，功能未启动。请检查 index.html 里的 id。");
    return;
  }

  var busy = false;
  var loaded = false;

  /* ---------- 配置是否已经填好 ---------- */
  function isConfigured() {
    return !!(
      cfg.url &&
      cfg.anonKey &&
      /^https?:\/\//.test(cfg.url) &&
      cfg.url.indexOf("YOUR_") === -1
    );
  }

  function endpoint() {
    return cfg.url.replace(/\/+$/, "") + "/rest/v1/" + (cfg.boardTable || "messages");
  }

  function headers() {
    return {
      "apikey": cfg.anonKey,
      "Authorization": "Bearer " + cfg.anonKey
    };
  }

  /* ---------- 状态提示 ---------- */
  function setStatus(kind, text) {
    statusEl.setAttribute("data-kind", kind || "");
    statusEl.textContent = text || "";
  }

  function setState(text) {
    stateEl.textContent = text;
    stateEl.hidden = false;
  }

  /* ---------- 时间显示：把服务端时间换成"好读的样子" ---------- */
  function pad(n) { return (n < 10 ? "0" : "") + n; }

  function formatTime(raw) {
    if (!raw) return "";
    var d = new Date(raw);
    if (isNaN(d.getTime())) return String(raw);
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) +
           " " + pad(d.getHours()) + ":" + pad(d.getMinutes());
  }

  /* ---------- 渲染一条留言 ---------- */
  function buildItem(row) {
    var item = document.createElement("article");
    item.className = "board__item";

    var head = document.createElement("div");
    head.className = "board__item-head";

    var who = document.createElement("span");
    who.className = "board__who";
    /* textContent：昵称里的尖括号也只是普通文字，不会被当成标签执行 */
    who.textContent = (row && row.name && String(row.name).trim()) || "匿名";

    var time = document.createElement("time");
    time.className = "board__time";
    time.textContent = formatTime(row && row.created_at);

    head.appendChild(who);
    head.appendChild(time);

    var text = document.createElement("p");
    text.className = "board__text";
    text.textContent = (row && row.message) ? String(row.message) : "";

    item.appendChild(head);
    item.appendChild(text);
    return item;
  }

  function renderList(rows) {
    /* 清空（只清自己生成的卡片，state 段落留着复用） */
    Array.prototype.slice.call(listEl.querySelectorAll(".board__item"))
      .forEach(function (el) { listEl.removeChild(el); });

    if (!rows || !rows.length) {
      setState("墙上还没有留言，你可以当第一个。");
      if (moreEl) moreEl.hidden = true;
      return;
    }

    stateEl.hidden = true;
    var frag = document.createDocumentFragment();
    rows.forEach(function (row) { frag.appendChild(buildItem(row)); });
    listEl.appendChild(frag);

    /* 拉满 LIMIT 条时，老实告诉访客"这里不是全部" */
    if (moreEl) moreEl.hidden = !(rows.length >= LIMIT);
  }

  /* ---------- 拉取留言 ---------- */
  function loadBoard() {
    if (!isConfigured()) {
      setState("留言板还没接通后台，暂时打不开。你可以先写在下面，用邮件发给我。");
      if (fallbackEl) fallbackEl.hidden = false;
      return Promise.resolve(false);
    }

    listEl.setAttribute("aria-busy", "true");
    setState("正在打开留言板…");

    var url = endpoint() +
      "?select=id,name,message,created_at" +
      "&order=created_at.desc" +
      "&limit=" + LIMIT;

    var opts = { method: "GET", headers: headers() };
    var timer = null;
    var ctrl = null;

    if (typeof AbortController === "function") {
      ctrl = new AbortController();
      opts.signal = ctrl.signal;
      timer = setTimeout(function () { ctrl.abort(); }, cfg.timeoutMs || 12000);
    }

    return fetch(url, opts)
      .then(function (res) {
        if (!res.ok) {
          return res.text().then(function (body) {
            throw new Error("HTTP " + res.status + (body ? " · " + body.slice(0, 120) : ""));
          });
        }
        return res.json();
      })
      .then(function (rows) {
        loaded = true;
        renderList(rows);
        return true;
      })
      .catch(function (err) {
        setState("留言板没打开成功（" + err.message + "）。不耽误你写，写完照样能贴上去。");
        return false;
      })
      .then(function (ok) {
        if (timer) clearTimeout(timer);
        listEl.setAttribute("aria-busy", "false");
        return ok;
      });
  }

  /* ---------- 兜底通道：复制 + 邮件 ---------- */
  function composeText() {
    var name = (nameEl.value || "").trim();
    var msg = (msgEl.value || "").trim();
    return (name ? name + "：" : "匿名：") + msg;
  }

  function copyText(text) {
    if (window.navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text).then(function () { return true; },
                                                       function () { return legacyCopy(text); });
    }
    return Promise.resolve(legacyCopy(text));
  }

  function legacyCopy(text) {
    try {
      var ta = document.createElement("textarea");
      ta.value = text;
      ta.setAttribute("readonly", "readonly");
      ta.style.position = "fixed";
      ta.style.top = "-1000px";
      document.body.appendChild(ta);
      ta.select();
      var ok = document.execCommand("copy");
      document.body.removeChild(ta);
      return ok;
    } catch (e) {
      return false;
    }
  }

  function mailtoLink() {
    return "mailto:" + MAIL +
      "?subject=" + encodeURIComponent("留言板") +
      "&body=" + encodeURIComponent(composeText());
  }

  /* ---------- 提交 ---------- */
  function submit(e) {
    if (e && e.preventDefault) e.preventDefault();
    if (busy) return;

    var message = (msgEl.value || "").trim();

    if (!message) {
      setStatus("err", "还没写内容呢，写一句就能贴上去。");
      msgEl.focus();
      return;
    }

    /* 后台没配好：走复制 + 邮件，且明确说"没贴到墙上" */
    if (!isConfigured()) {
      var text = composeText();
      copyText(text).then(function (ok) {
        if (ok) {
          setStatus("tip", "留言板还没接通 —— 已经帮你复制好了，邮件窗口也一起打开了，直接发给我就行。");
        } else {
          setStatus("tip", "留言板还没接通，也没能自动复制。已经帮你选中内容，按 Ctrl+C 复制后邮件发我吧。");
          msgEl.focus();
          msgEl.select();
        }
        window.location.href = mailtoLink();
      });
      return;
    }

    busy = true;
    submitBtn.disabled = true;
    setStatus("tip", "正在贴到墙上…");

    var payload = {
      name: (nameEl.value || "").trim() || null,
      message: message
    };

    var opts = {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "apikey": cfg.anonKey,
        "Authorization": "Bearer " + cfg.anonKey,
        "Prefer": "return=minimal"
      },
      body: JSON.stringify(payload)
    };

    var timer = null;
    var ctrl = null;

    if (typeof AbortController === "function") {
      ctrl = new AbortController();
      opts.signal = ctrl.signal;
      timer = setTimeout(function () { ctrl.abort(); }, cfg.timeoutMs || 12000);
    }

    fetch(endpoint(), opts)
      .then(function (res) {
        if (!res.ok) {
          return res.text().then(function (body) {
            throw new Error("HTTP " + res.status + (body ? " · " + body.slice(0, 120) : ""));
          });
        }
        return null;
      })
      .then(function () {
        msgEl.value = "";
        if (countEl) countEl.textContent = "0";
        setStatus("ok", "贴上去了，谢谢你留的这一句！");
        /* 贴完重新拉一遍：以服务器返回的为准，不自己编卡片 */
        return loadBoard();
      })
      .catch(function (err) {
        /* 失败时什么都不清空：内容还在框里，可以直接再点一次 */
        setStatus("err", "没贴上去，内容我帮你留着了，可以再点一次试试。（" + err.message + "）");
      })
      .then(function () {
        if (timer) clearTimeout(timer);
        busy = false;
        submitBtn.disabled = false;
      });
  }

  form.addEventListener("submit", submit);

  /* 字数计数器 */
  function updateCount() {
    if (countEl) countEl.textContent = String((msgEl.value || "").length);
  }
  msgEl.addEventListener("input", updateCount);
  updateCount();

  /* 复制按钮（兜底通道里显示） */
  if (copyBtn) {
    copyBtn.addEventListener("click", function () {
      copyText(composeText()).then(function (ok) {
        setStatus(ok ? "ok" : "err", ok ? "已经复制好了，粘到邮件里发我就行。" : "没能自动复制，手动选中复制一下吧。");
      });
    });
  }

  /* 打开页面就拉一次 */
  loadBoard();
})();
