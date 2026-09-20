/* =========================================================
   数字分身 —— 预设问答（零依赖 / 零网络请求）

   它是什么：
     一个"只会说作者写好的话"的分身。访客点话题 → 分身从预设里回答。
     **没有接任何大模型，页面不会向外发一个字节**（对比 feedback.js 是唯一
     会联网的文件）。这样做的好处是：GitHub Pages 纯静态就能跑，
     不花钱、不泄密、不怕接口挂掉。

   想改分身的台词：只改下面 TWIN 这一个对象，其它代码都不用动。
      - greeting : 打开对话框时它说的第一句话
      - topics   : 访客能点的问题（q 是问题，a 是分身的回答）
      - ending   : 所有话题都问完之后它说的话

   ⚠ 如果回答里出现新的汉字，记得重建字体子集（tools/resubset.ps1），
     否则新字会回退成系统字体（详见 assets/fonts/README.md）。
   ========================================================= */

(function () {
  "use strict";

  /* =========================================================
     ↓↓↓ 分身的全部台词 ↓↓↓
     调子：温和，但有距离 —— 愿意回答你，也始终留着一层。
     改台词只改这一个对象，下面的代码都不用动。
     ========================================================= */
  var TWIN = {
    greeting: "你好。想聊什么都可以，我先听着。",

    topics: [
      {
        q: "你是谁？",
        a: "刘俊廷的影子。他不太擅长应付寒暄，就把这几句话交给我了。"
      },
      {
        q: "你为什么话这么少？",
        a: "不是不愿意说。只是说完之后常常觉得不太准确，索性就少说一点。"
      },
      {
        q: "你平时读什么？",
        a: "近代史。读得越多越不敢下判断，同一件事总有两三种讲法，都站得住脚。"
      },
      {
        q: "你谈过恋爱吗？",
        a: "没有。这件事我还没想清楚，也不想随便找个人来试。"
      },
      {
        q: "INFJ 是不是很会看人？",
        a: "大概能看出来一点。不过看出来了也未必要说，说破了对方会不自在。"
      },
      {
        q: "为什么你让人捉摸不透？",
        a: "我只是没把话说满。你要是愿意多问几句，我也许会多说一点。"
      },
      {
        q: "你觉得自己真实吗？",
        a: "不算真实。但和你聊的这些，我没有打算骗你。"
      }
    ],

    ending: "先到这儿吧。剩下的，还是留给他本人说比较好。"
  };
  /* =========================================================
     ↑↑↑ 台词到此为止，下面是交互逻辑 ↑↑↑
     ========================================================= */

  var modal   = document.getElementById("dtModal");
  var openBtn = document.getElementById("dtOpen");
  var logEl   = document.getElementById("dtLog");
  var rowEl   = document.getElementById("dtPicksRow");
  var labelEl = document.getElementById("dtPicksLabel");
  // 兜底写法：早先这里只找 id="dtPicks"，而 HTML 上只有 class="dt-picks"，
  // picksEl 为 null 会让下面整个脚本 return —— 按钮、问答、深链全部失效，
  // 而且不报错、看不出问题。两种写法都认，并加校验防回归（tools/verify_v35.ps1）。
  var picksEl = document.getElementById("dtPicks") ||
                (modal && modal.querySelector(".dt-picks"));

  if (!modal || !openBtn || !logEl || !picksEl || !rowEl) return;

  var panel = modal.querySelector(".dt-modal__panel");
  var lastFocus = null;
  var asked = 0;
  var started = false;
  var busy = false;

  /* 优先减少动效的用户：不做"正在输入"的等待 */
  function reduceMotion() {
    return window.matchMedia &&
           window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  /* ---------- 往对话记录里追加一条气泡 ---------- */
  function pushMessage(role, text) {
    var wrap = document.createElement("div");
    wrap.className = "dt-msg dt-msg--" + role;

    var face = document.createElement("span");
    face.className = "dt-msg__face";
    face.setAttribute("aria-hidden", "true");
    face.textContent = role === "twin" ? "🌙" : "🙂";

    var body = document.createElement("p");
    body.className = "dt-msg__body";
    body.textContent = text;

    wrap.appendChild(face);
    wrap.appendChild(body);
    logEl.appendChild(wrap);
    logEl.scrollTop = logEl.scrollHeight;
    return wrap;
  }

  function pushTyping() {
    var wrap = document.createElement("div");
    wrap.className = "dt-msg dt-msg--twin dt-typing";

    var face = document.createElement("span");
    face.className = "dt-msg__face";
    face.setAttribute("aria-hidden", "true");
    face.textContent = "🌙";

    var body = document.createElement("p");
    body.className = "dt-msg__body";
    body.setAttribute("aria-hidden", "true");
    for (var i = 0; i < 3; i++) body.appendChild(document.createElement("i"));

    wrap.appendChild(face);
    wrap.appendChild(body);
    logEl.appendChild(wrap);
    logEl.scrollTop = logEl.scrollHeight;
    return wrap;
  }

  /* ---------- 话题按钮 ---------- */
  function buildPicks() {
    rowEl.textContent = "";
    for (var i = 0; i < TWIN.topics.length; i++) {
      makePick(i);
    }
    labelEl.textContent = "你可以问他：";
  }

  function makePick(index) {
    var t = TWIN.topics[index];
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "dt-pick";
    btn.textContent = t.q;
    btn.setAttribute("data-dt-index", String(index));
    btn.addEventListener("click", function () { ask(index, btn); });
    rowEl.appendChild(btn);
    return btn;
  }

  function makeRestart() {
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "dt-pick dt-pick--ghost";
    btn.textContent = "从头再问一遍";
    btn.addEventListener("click", function () {
      asked = 0;
      logEl.textContent = "";
      buildPicks();
      start();
    });
    rowEl.appendChild(btn);
  }

  function makeAskAgain() {
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "dt-pick dt-pick--ghost";
    btn.textContent = "再问一个";
    btn.addEventListener("click", function () {
      labelEl.textContent = "你可以问他：";
      rowEl.textContent = "";
      buildPicks();
    });
    rowEl.appendChild(btn);
  }

  /* ---------- 一次问答 ---------- */
  function ask(index, btn) {
    if (busy) return;
    busy = true;

    var t = TWIN.topics[index];
    pushMessage("me", t.q);
    if (btn) btn.disabled = true;

    var typing = reduceMotion() ? null : pushTyping();
    var delay = reduceMotion() ? 0 : 520 + Math.round(t.a.length * 4);

    window.setTimeout(function () {
      if (typing && typing.parentNode) typing.parentNode.removeChild(typing);
      pushMessage("twin", t.a);
      asked++;

      if (asked >= TWIN.topics.length) {
        pushMessage("twin", TWIN.ending);
        labelEl.textContent = "没有别的话题了。";
        rowEl.textContent = "";
        makeRestart();
      } else {
        labelEl.textContent = "还想问别的吗？";
        rowEl.textContent = "";
        makeAskAgain();
      }
      busy = false;
    }, delay);
  }

  /* ---------- 开场 ---------- */
  function start() {
    if (started) return;
    started = true;
    pushMessage("twin", TWIN.greeting);
    buildPicks();
  }

  /* ---------- 打开 / 关闭 ---------- */
  function openModal() {
    lastFocus = document.activeElement;
    modal.hidden = false;
    document.body.classList.add("dt-locked");
    start();
    if (panel) panel.focus();
    logEl.scrollTop = logEl.scrollHeight;
  }

  function closeModal() {
    modal.hidden = true;
    document.body.classList.remove("dt-locked");
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }

  openBtn.addEventListener("click", openModal);

  Array.prototype.forEach.call(
    modal.querySelectorAll("[data-dt-close]"),
    function (el) { el.addEventListener("click", closeModal); }
  );

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && !modal.hidden) closeModal();
  });

  /* 直接用 #twin-chat 打开对话框（方便分享链接 / 截图）
     （#twin 是专区板块本身的锚点，留给导航跳转用） */
  if (window.location.hash === "#twin-chat") openModal();
})();
