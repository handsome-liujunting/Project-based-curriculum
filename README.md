# 个人主页（V4）

刘俊廷的个人主页 —— 课程作业「基于项目的学习」系列成果之一，也是我用 Vibe Coding 从零一路改到第四版的作品。

**线上地址**：https://handsome-liujunting.github.io/Project-based-curriculum/
**当前版本**：**V4**（版本号只有一个来源：`js/feedback-config.js` 里的 `siteVersion`）

> V4 相对 V3.5 只做了两类事：**把"改动过程"搬到页面上**（新增「迭代历程」区块，含 V1→V4 版本目录），以及**修掉几处"能用但不体面"的问题**（版本号、报错文案、作品区口径、字体缺字）。
> 站点的设计语言（美漫/波普、粗描边、网点、跑马灯、两款自托管字体）与 V3 / V3.5 保持一致，**没有推倒重来**。

---

## 四次改版（一页看清）

| 版本 | 日期 | 提交 | 一句话 | 主要改动 |
|---|---|---|---|---|
| V1 | 2026-09-05 | `f7aa66e` | 先让它能打开 | 语义化 HTML + 响应式 CSS，蓝色主色，卡片说明"我是谁、会什么、怎么找我" |
| V2 | 2026-09-10 | `4062811` | 换成卡片化排版 | 卡片化布局 + 暖色，导航加编号，首屏写正经自我介绍 |
| V3 | 2026-09-12 | `dcdb257` | 整站重画成美漫风 | 粗描边、半调网点、对话气泡、放射背景、楼群剪影、跑马灯；自托管字体 |
| V3.5 | 2026-09-21 | `6bb6ec2` | 不动设计，先加通道 | 只加反馈入口与公开留言板（接 Supabase 真后台），便于与 V3 逐项对照 |
| **V4** | **2026-10-06** | **`7a76419`** | **把过程摆出来** | **迭代历程区块（含版本目录）+ 版本号推到 V4 + 反馈可用性修复 + 作品区口径修正** |

V4 之上还有一次小补丁 `6f501cb`（历程区块加版本目录后的收尾与文档校准）；**最新提交以仓库首页为准**。

**每一版都能回去看**：`git checkout f7aa66e`（V1）、`4062811`（V2）、`dcdb257`（V3）、`6bb6ec2`（V3.5）、`7a76419`（V4）。

---

## 站点包含什么

按导航顺序排列（共 8 个 `<section>`，顶部导航 7 个入口 + 首屏）：

| 区块 | 标题 / 内容 |
|---|---|
| 首屏 `#top` | 「刘俊廷！」+ 专业与爱好 + 对话气泡「你好，我是刘俊廷，很高兴认识你！」+ 楼群剪影 |
| 故事 `#story` | 「故事，从一行代码开始：」——三个格子（第一格 / 第二格 / 第三格） |
| 技能 `#skills` | 「技能与兴趣！」——分组标签（技术栈 / 运动 / 阅读写作…） |
| 作品 `#works` | 「近期战绩！」——与迭代历程口径一致的成果卡 |
| **历程 `#iterations`（V4 新增）** | 「四次改版，越改越像我」——每版首屏缩略图 + 改了什么、为什么 + 提交号；**区块顶部还有一排 V1→V4 版本目录** |
| 分身 `#twin` | 「数字分身」——预设问答的本地对话（零联网、无 AI 接口） |
| 留言板 `#board` | 公开留言墙：访客写一句 → 存进后台 → 展示给所有来访的人 |
| 联系 `#contact` | 「每个主角都有自己的开场白」——邮箱与所在地 |
| 常驻入口 | 右下角「提个意见」按钮 → 私密反馈表单（只有作者能看到） |
| 页脚 | 跑马灯（姓名/专业/爱好/所在地循环）+ 导航 + 「提个意见」 |

故事区块与技能区块之间还有一条黄色跳转条「想看看我做过什么吗？」→ 直达作品区。

数字分身是**预设问答**：所有回答都写在 `js/digital-twin.js` 里，怎么点都不产生任何网络请求，也不对接大模型。

**历程区块的版本目录**：4 个胶囊（V1 / V2 / V3 / V4）放在区块最上面，点一下直达对应卡片；四张卡都带 `scroll-margin-top: 96px`，落点不会被 sticky 顶栏盖住。加它的原因很实际——桌面两列排版会把 V3/V4 挤到第二行，滚到这一节时第一屏只完整显示 V1、V2，很容易被读成"只做了两版"。

---

## V4 改了什么（相对 V3.5）

1. **新增「迭代历程」区块**：把"我改过什么、为什么改"从口述变成访客能自己看的东西。
2. **历程区块加版本目录**：解决"内容都在，但第一眼看不出有四个版本"的可发现性问题。
3. **反馈可用性修复**：上报的版本号回到唯一来源（`feedback-config.js`）；后台不可达时不再把英文 `Failed to fetch` 甩给访客，改成"网络好像不通，不影响别的"，原始信息只留在 console。
4. **作品区口径修正**：不再把同一个项目当两个作品，文案与迭代历程对齐；数字分身如实标注为"本地关键词匹配"。
5. **字体子集重建**：新文案里出现的缺字（方框）补进子集，432 个汉字全覆盖，仍不依赖外部字体服务。

**刻意没做的（都在 `docs/V4-反馈决策表.md` 里写了理由）：**

- **不换 `supabase-js`**：前端只做"写一条、读一列"，原生 `fetch` 足够，不值得为省几行代码多一个依赖。
- **迭代缩略图暂不加懒加载**：收益有限，却要同时改导出（内联）、同步、截图三条链路 —— 记为下次加图时的第一步。
- **留言板不加登录门槛**：匿名墙的意图就是"随便留一句"，加登录只会劝退人。

---

## 目录结构

```
/                      ← 仓库根 = GitHub Pages 发布根
├── index.html         ← 站点主页（源码在 outputs/personal-homepage-v35/，同步而来）
├── css/               ← style.css、iterations.css、feedback.css、board.css、digital-twin.css
├── js/                ← main.js、feedback-config.js、feedback.js、digital-twin.js、board.js
├── assets/fonts/      ← 两个字体子集 + OFL 授权全文 + 说明
├── assets/img/        ← 历程区块的 4 张版本缩略图（iter-v1…v4.jpg）
├── outputs/           ← 各版本源码、单文件离线版、截图、说明报告（不参与发布）
├── docs/              ← 制作文档、后台接入说明、发布清单、回归清单、反馈决策表、反思
├── tools/             ← 校验 / 导出 / 同步 / 截图 / 探针 / 自检脚本
└── uploads/           ← 课件与参考素材（不入库）
```

历史版本保留在 `outputs/` 里（`personal-homepage-v1` … `personal-homepage-v35`），方便对照与回滚；根目录只放当前要发布的那一份。

---

## 反馈与留言板怎么工作的

```
反馈（私密）   访客填表 → fetch POST → Supabase PostgREST (/rest/v1/feedback) → feedback 表
留言板（公开） 访客留言 → fetch POST → Supabase PostgREST (/rest/v1/messages) → messages 表
                                                          ↑ 页面 GET 读取，倒序显示最近 30 条
```

两张表都是「只许插入，不许改删」的思路，差别只在读取：

- `feedback`：只有 INSERT 策略，**连 select 都没有** —— 访客写了什么，只有作者在控制台能看到。
- `messages`：多开一条 **SELECT 策略**，页面才能把留言渲染出来；update / delete 全部拒绝，
  所以谁都改不了、删不了别人的留言，需要删除时由作者在控制台处理。
- 留言渲染一律走 `textContent`（不拼 HTML），昵称限 20 字 / 内容限 280 字，防注入。
- 前端只用 **publishable key**（旧称 anon key），它本来就可以公开。
  **secret / service_role key 与数据库密码永不进前端、也不进仓库。**
- 看反馈走 Supabase 控制台（Table Editor），页面上不开任何读取入口。

**目前真实的数据状态（截至 2026-10-06）：**

- **公开留言板：4 条真实留言**（`id 5–8`，2026-09-21 陆续留下：家人、师长与一位路过的访客），已渲染在线上。
- **私有反馈表单：0 条** —— 入口是通的，但我**没有往里面写测试数据充数**：凑出来的"反馈"不算反馈。
  收到第一条起就按 `docs/V4-反馈决策表.md` 的流程走（先复现 → 分类 → 四种决定选一 → 回归 → 追加决策表）。
- 只读复验结论：CORS 预检 200、匿名**读不到** feedback（401）、改 / 删一律 401、空内容与超长内容被数据库拒收。

建表脚本：`docs/V3.5-建表与RLS.sql`
接入步骤：`docs/V3.5-反馈后台接入说明.md`

> 后台没接通时页面会**明说**"后台还没配置好"，留言板则退化成"复制这句话 + 邮件发我"，两个入口都不假装成功。

---

## 本地预览

```powershell
# A. 预览还没推送的改动（源码目录，端口 8791）
powershell -NoProfile -ExecutionPolicy Bypass -File tools\serve_site.ps1 -Root "outputs\personal-homepage-v35" -Port 8791
#    → 浏览器打开 http://127.0.0.1:8791/

# B. 预览发布根那一份（等价于线上，端口 8123）
powershell -NoProfile -ExecutionPolicy Bypass -File tools\serve_v35.ps1
#    → 浏览器打开 http://127.0.0.1:8123/
```

两者都是纯 PowerShell 的小静态服务器（**不需要 node / python**）。必须走 `http://`：字体在 `file://` 下会被浏览器拒载。

**完全离线**：直接双击 `outputs/personal-homepage-v35-standalone/index.html` —— 单文件版（515760 B），CSS / JS / 4 张图片全部内联，断网也不掉图。

---

## 校验与自检

```powershell
# 1) 站点结构 / 资源存在性 / id 唯一 / JS↔HTML 契约 / 外链 / 密钥扫描
powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify_v35.ps1 -Root "outputs\personal-homepage-v35"

# 2) 发布根再校验一次（同步后必须跑；-SiteOnly 只扫站点文件）
powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify_v35.ps1 -Root "." -SiteOnly

# 3) 同步源码 → 发布根
powershell -NoProfile -ExecutionPolicy Bypass -File tools\sync_site.ps1 -Src "outputs\personal-homepage-v35" -Dst "."

# 4) 重新导出单文件离线版
powershell -NoProfile -ExecutionPolicy Bypass -File tools\export_single_file.ps1 -Src "outputs\personal-homepage-v35" -OutHtml "outputs\personal-homepage-v35-standalone\index.html"

# 5) 几何探针：量各区块坐标与文档高度（改版后核对数字）
powershell -NoProfile -ExecutionPolicy Bypass -File tools\probe_v35.ps1 -Root "outputs\personal-homepage-v35" -Width 1440 -TallH 900

# 6) 反馈链路验收（接好 Supabase 后；-Post 会真插一条带标记的测试行并打印清理 SQL）
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check_feedback.ps1 -Post

# 7) 公开留言板验收（默认只读；-Post 才会真留一条，平时别加）
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check_board.ps1
```

**当前自检结果**：`verify_v35.ps1` FAIL count = 0 —— 43 个 id 无重复、主要容器标签配平（18 组）、JS↔HTML 契约（25 个 id / data 属性）逐条对上、无 HTML 字符串拼接（只走 `textContent`）、前端无密钥材料；同步后根目录与源码**逐字节一致**（SHA256）；单文件版 `images ok 4/4 as data URI`。

体积口径：站点 `index.html` 32673 B ｜ CSS 合计 52184 B ｜ JS 合计 33563 B ｜ 单文件版 515760 B。

---

## 文档

| 文件 | 内容 |
|---|---|
| `outputs/个人主页-V1到V4-总汇总.md` | **说明报告**：a) 开发历史 b) 新增/修改功能 c) 问题与解决 d) 反馈与决策 e) 回归测试 f) 版本记录 g) 反思摘要 h) 证据/安全/复现 |
| `outputs/报告.html` | 上面那份报告的网页版（图片已内联，可直接用浏览器打印成 PDF） |
| `docs/V3.5→V4-迭代记录.md` | 从 V3.5 到 V4 的逐项改动与验证记录 |
| `docs/V4-回归测试清单.md` | 桌面 / 手机逐项回归清单与实测数字 |
| `docs/V4-反馈决策表.md` | 反馈 → 复现 → 四种决定（Accept/Modify/Delay/Reject）的完整表 |
| `docs/V4-反思.md` | 这一版做得好与不好的地方，以及下次先做什么 |
| `docs/V3.5-反馈后台接入说明.md` | Supabase 接入六步、自测、报错对照表、安全红线 |
| `docs/V3.5-发布检查清单.md` | 发布前检查、逐屏 18 项、上线信息与回滚 |
| `docs/V3.5-建表与RLS.sql` | 建表 + 行级安全策略（可直接粘进 SQL Editor） |
| `docs/V3.5-素材许可台账.md` | 素材来源与许可登记 |

---

## 作业提交物

- **主页链接**：https://handsome-liujunting.github.io/Project-based-curriculum/
- **说明报告**：`outputs/个人主页-V1到V4-总汇总.md`（网页版 `outputs/报告.html`，PDF 由它打印，命名按课程要求）
- **可直接离线打开的版本**：`outputs/personal-homepage-v35-standalone/index.html`

---

## 素材与许可

- 字体：**ZCOOL KuaiLe**（站酷快乐体）、**Bangers** —— 均为 OFL 授权，授权全文见 `assets/fonts/`。
- 图片：页面上的插图与版本缩略图都是我自己各版本的页面截图，无第三方素材。
- 参考了同系列课件的**做法与结构**，未使用其品牌名、标志、角色形象、插画或原文案。
