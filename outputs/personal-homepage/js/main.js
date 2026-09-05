/* 刘俊廷 · 个人主页 V1 —— JS 交互脚本 */
/* 符合课件要求：JS 负责「行为与交互」，与 HTML/CSS 分离 */

(function () {
  "use strict";

  // 移动端汉堡菜单：切换 is-open 类，控制展开/收起（对应课件知识点⑤）
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
      });
    });
  }

  // 一个小交互：数字分身输入框聚焦提示（原型占位，仅增强体验）
  var send = document.querySelector(".dialogue-box__send");
  var input = document.querySelector(".dialogue-box__input span");
  if (send && input) {
    send.addEventListener("click", function () {
      input.textContent = "原型占位，即将接入真实问答能力……";
      send.textContent = "敬请期待";
    });
  }
})();
