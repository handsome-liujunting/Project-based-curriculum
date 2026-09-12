/* =========================================================
   V3 —— 交互脚本（零依赖）
   1) 滚动淡入（尊重 prefers-reduced-motion，并兜底无 IntersectionObserver）
   2) 顶部阅读进度条 + 各分区进度轨 + 装饰滚动联动
   3) 顶部导航锚点高亮
   ========================================================= */

(function () {
  "use strict";

  var reduce =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- 1. 滚动淡入 ---------- */
  var items = document.querySelectorAll(".reveal");

  if (reduce || !("IntersectionObserver" in window)) {
    // 降级：直接全部显示
    Array.prototype.forEach.call(items, function (el) {
      el.classList.add("is-visible");
    });
  } else {
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );
    Array.prototype.forEach.call(items, function (el) {
      io.observe(el);
    });
  }

  /* ---------- 2. 阅读进度条 + 分区进度轨 + 滚动联动（装饰跟着滚） ---------- */
  var bar = document.getElementById("progressBar");
  var rails = document.querySelectorAll(".section > .rail");
  var rays = document.querySelector(".rays");
  var burst = document.querySelector(".burst");
  var sfxCta = document.querySelector(".sfx--cta");
  var sfxWorks = document.querySelector(".sfx--works");

  function paint() {
    var doc = document.documentElement;
    var max = doc.scrollHeight - doc.clientHeight;
    var y = window.pageYOffset || doc.scrollTop || 0;
    var p = max > 0 ? Math.min(1, Math.max(0, y / max)) : 0;

    // 进度条属于功能性指示，降级模式下也保留
    if (bar) bar.style.transform = "scaleX(" + p + ")";

    // 每个分区的阅读进度：先批量读 rect，再批量写样式，
    // 避免"读-写-读-写"交替触发反复重排
    if (rails.length) {
      var vh = doc.clientHeight;
      var i, rect, prog;
      var boxes = [];
      for (i = 0; i < rails.length; i++) {
        boxes.push(rails[i].parentNode.getBoundingClientRect());
      }
      for (i = 0; i < rails.length; i++) {
        rect = boxes[i];
        // 分区顶边刚进视口 -> 0；分区底边刚离开视口 -> 1
        prog = (vh - rect.top) / (rect.height + vh);
        prog = prog < 0 ? 0 : prog > 1 ? 1 : prog;
        rails[i].style.setProperty("--p", prog.toFixed(4));
      }
    }

    if (reduce) return; // 装饰性视差在"减少动态"下关闭
    if (rays) rays.style.translate = "-50% calc(-50% + " + (y * 0.08).toFixed(1) + "px)";
    if (burst) burst.style.rotate = (-12 + y * 0.03).toFixed(1) + "deg";
    if (sfxCta) sfxCta.style.rotate = (8 + y * 0.05).toFixed(1) + "deg";
    if (sfxWorks) sfxWorks.style.rotate = (-14 - y * 0.05).toFixed(1) + "deg";
  }

  var ticking = false;
  function requestPaint() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(function () {
      ticking = false;
      paint();
    });
  }

  if (window.addEventListener) {
    window.addEventListener("scroll", requestPaint, { passive: true });
    window.addEventListener("resize", requestPaint);
  }
  paint();

  /* ---------- 3. 导航锚点高亮 ---------- */
  var links = document.querySelectorAll(".topbar__nav a");
  if (!links.length || !("IntersectionObserver" in window)) return;

  var map = {};
  Array.prototype.forEach.call(links, function (a) {
    var id = a.getAttribute("href").slice(1);
    var target = document.getElementById(id);
    if (target) map[id] = a;
  });

  var spy = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        var a = map[entry.target.id];
        if (!a) return;
        if (entry.isIntersecting) {
          Array.prototype.forEach.call(links, function (l) {
            l.removeAttribute("aria-current");
          });
          a.setAttribute("aria-current", "true");
        }
      });
    },
    { threshold: 0.4 }
  );

  Object.keys(map).forEach(function (id) {
    spy.observe(document.getElementById(id));
  });
})();
