/* =========================================================
   刘俊廷 · 个人主页 V2 —— JS 交互脚本
   职责：行为与交互（与 HTML/CSS 分离）
   包含：移动端菜单、导航滚动态、滚动淡入、数字分身占位交互
   ========================================================= */

(function () {
  "use strict";

  /* ---------- 1. 移动端汉堡菜单 ---------- */
  var toggle = document.getElementById("navToggle");
  var menu = document.getElementById("navMenu");

  if (toggle && menu) {
    toggle.addEventListener("click", function () {
      var open = menu.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
      toggle.setAttribute("aria-label", open ? "关闭菜单" : "展开菜单");
    });

    // 点击菜单项后自动收起
    menu.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        menu.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
        toggle.setAttribute("aria-label", "展开菜单");
      });
    });
  }

  /* ---------- 2. 顶部导航：滚动后加阴影 ---------- */
  var header = document.getElementById("siteHeader");
  if (header) {
    var onScroll = function () {
      header.classList.toggle("is-scrolled", window.scrollY > 8);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* ---------- 3. 滚动淡入（IntersectionObserver） ---------- */
  var revealItems = document.querySelectorAll(".reveal");
  var reduceMotion = window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (!reduceMotion && "IntersectionObserver" in window) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -40px 0px" });

    revealItems.forEach(function (el) { observer.observe(el); });
  } else {
    // 降级：直接显示
    revealItems.forEach(function (el) { el.classList.add("is-visible"); });
  }

  /* ---------- 4. 数字分身输入框（静态原型占位） ---------- */
  var send = document.getElementById("dialogueSend");
  var placeholder = document.querySelector(".dialogue__placeholder");
  if (send && placeholder) {
    send.addEventListener("click", function () {
      placeholder.textContent = "原型占位，即将接入真实问答能力……";
      send.textContent = "敬请期待";
      send.disabled = true;
    });
  }
})();
