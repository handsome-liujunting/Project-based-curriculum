/* =========================================================
   V3.5 新增 —— 反馈入口 / 反馈表单（零依赖）

   做什么：
     1) 页面右下角的入口按钮 → 打开模态表单（不跳转页面）
     2) 访客填写 → 直接 POST 到 Supabase 的 REST 接口 → 存进 feedback 表
     3) 提交中禁用按钮防重复点击；失败保留已填内容；成功给明确提示
     4) 未配置后台时，明确告诉访客"通道还没接好"，不假装成功

   为什么不用 supabase-js：
     官方客户端库要靠 CDN 或打包工具引入，这里只需要"插入一行"这一个动作，
     用 fetch 直接打 PostgREST 接口就够了 —— 不引入第三方库，
     页面运行时依然没有额外依赖。
   ========================================================= */

(function () {
  "use strict";

  var cfg = window.FEEDBACK_CONFIG || {};

  var modal     = document.getElementById("fbModal");
  var openBtn   = document.getElementById("fbOpen");
  var form      = document.getElementById("fbForm");
  var statusEl  = document.getElementById("fbStatus");
  var submitBtn = document.getElementById("fbSubmit");
  var noteEl    = document.getElementById("fbNote");

  if (!modal || !openBtn || !form || !statusEl || !submitBtn) return;

  var panel = modal.querySelector(".fb-modal__panel");
  var lastFocus = null;
  var busy = false;

  /* ---------- 配置是否已经填好 ---------- */
  function isConfigured() {
    return !!(
      cfg.url &&
      cfg.anonKey &&
      /^https?:\/\//.test(cfg.url) &&
      cfg.url.indexOf("YOUR_") === -1
    );
  }

  /* ---------- 状态提示 ---------- */
  function setStatus(kind, text) {
    statusEl.setAttribute("data-kind", kind || "");
    statusEl.textContent = text || "";
  }

  /* ---------- 打开 / 关闭 ---------- */
  function openModal() {
    lastFocus = document.activeElement;
    modal.hidden = false;
    document.body.classList.add("fb-locked");
    setStatus("tip", isConfigured() ? "" : "反馈通道还没接好，稍后配置完就能用了。");
    if (!isConfigured() && noteEl) noteEl.hidden = false;
    /* 焦点给到面板本身：既让键盘用户进入对话框，又不会在手机上直接弹出键盘 */
    if (panel) panel.focus();
  }

  function closeModal() {
    modal.hidden = true;
    document.body.classList.remove("fb-locked");
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }

  openBtn.addEventListener("click", openModal);

  Array.prototype.forEach.call(
    modal.querySelectorAll("[data-fb-close]"),
    function (el) { el.addEventListener("click", closeModal); }
  );

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && !modal.hidden) closeModal();
  });

  /* 直接用 #feedback 打开表单（方便分享链接 / 截图） */
  if (window.location.hash === "#feedback") openModal();

  /* ---------- 取值 ---------- */
  function pick(name) {
    var el = form.querySelector('input[name="' + name + '"]:checked');
    return el ? el.value : "";
  }

  /* ---------- 提交 ---------- */
  function submit(e) {
    if (e && e.preventDefault) e.preventDefault();
    if (busy) return;

    var message = (form.elements.message.value || "").trim();
    var device  = pick("device");
    var relation = pick("relation");

    if (!message) {
      setStatus("err", "内容还是空的，写一句话就能提交。");
      form.elements.message.focus();
      return;
    }
    if (!device) {
      setStatus("err", "选一下这条反馈是在哪种设备上遇到的吧。");
      return;
    }

    if (!isConfigured()) {
      setStatus("tip", "后台还没配置好，这条没发出去，内容我帮你留在框里了。");
      return;
    }

    var payload = {
      name:     (form.elements.name.value || "").trim() || null,
      relation: relation || null,
      device:   device,
      message:  message,
      version:  cfg.siteVersion || ""
    };

    busy = true;
    submitBtn.disabled = true;
    setStatus("tip", "正在提交…");

    var headers = {
      "Content-Type": "application/json",
      "apikey": cfg.anonKey,
      "Authorization": "Bearer " + cfg.anonKey,
      "Prefer": "return=minimal"
    };

    var opts = { method: "POST", headers: headers, body: JSON.stringify(payload) };
    var timer = null;
    var ctrl = null;

    if (typeof AbortController === "function") {
      ctrl = new AbortController();
      opts.signal = ctrl.signal;
      timer = setTimeout(function () { ctrl.abort(); }, cfg.timeoutMs || 12000);
    }

    var url = cfg.url.replace(/\/+$/, "") + "/rest/v1/" + (cfg.table || "feedback");

    fetch(url, opts)
      .then(function (res) {
        if (!res.ok) {
          return res.text().then(function (body) {
            throw new Error("HTTP " + res.status + (body ? " · " + body.slice(0, 120) : ""));
          });
        }
        return null;
      })
      .then(function () {
        form.reset();
        setStatus("ok", "收到啦，谢谢你的意见！");
      })
      .catch(function (err) {
        /* 失败时什么都不清空：内容还在框里，可以直接再点一次 */
        setStatus("err", "没提交成功，内容我帮你留着了，可以再点一次试试。（" + err.message + "）");
      })
      .then(function () {
        if (timer) clearTimeout(timer);
        busy = false;
        submitBtn.disabled = false;
      });
  }

  form.addEventListener("submit", submit);
})();
