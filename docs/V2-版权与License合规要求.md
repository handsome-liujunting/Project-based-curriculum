# V2 版权与 License 合规要求（落实清单）

> 来源课件：`uploads/ses_f8f176931ffeUo08UbaMYf6zGk/个人主页打磨-V2设计借鉴课件.md`
> （该文件实为 PDF，共 39 页；课件标题《用 Vibe Coding 打磨你的个人主页》，V2 补充课件）
> 整理人：LIU JUNTING ｜ 整理日期：2026-09-10
> 用途：**V2 及后续所有版本的制作，必须逐条遵守本清单。交付前须对照第 8 节自检。**

---

## 0. 一句话底线

> **Reference ≠ Copy —— Copy the idea, not the assets.**
> （参考不等于复制；复制的是思路，不是素材。）

---

## 1. 四句必须记住的底线判断（课件 P39）

| 英文原文 | 中文含义 | 含义解读 |
|---|---|---|
| Reference ≠ Copy | 参考不等于复制 | 可以学思路，不能照搬成品 |
| Public ≠ Open Source | 公开不等于开源 | 能看到 ≠ 能随便用/改/发布 |
| Free ≠ Copyright Free | 免费不等于无版权 | 免费下载 ≠ 放弃版权 |
| Copy the idea, not the assets. | 复制思路，而不是素材 | 学方法、自己重新表达 |

> 课件原话：**"这三句 + 一句，就是你在公开自己作品前的底线判断。"**

---

## 2. 必须破除的常见误解（课件 P35）

以下理解**都不准确**，必须避免：

1. 公开网站 = 可以复制 ❌
2. 免费资源 = 可以随便用 ❌
3. GitHub public = 可以随便改 ❌
4. 模板能下载 = 可以随便发布 ❌
5. AI 能复刻 = 就一定可以发布 ❌

---

## 3. 必须区分的四种行为（课件 P35）

| 行为 | 是否合法 | 说明 |
|---|---|---|
| **Reference（参考）** | ✅ 合法 | 学思路、学方法 |
| **Reuse（复用）** | ⚠️ 合法但需看许可 | 必须先查 License |
| **Copy（复制）** | ⚠️ 分情况 | **复制思路可以，复制资源不行** |
| **Republish（重新发布）** | ⚠️ 需许可 | **需要许可，否则越界** |

---

## 4. 红黄绿灯（核心执行标准，课件 P36–P38）

### 🟢 GREEN 绿灯：Inspired By（通常安全，推荐）
- 学习**整体风格、色彩思路、信息层级、留白、布局原则**
- **自己重新实现**类似的卡片、类似的交互
- 使用**自己的文字、照片、项目**
- 使用**有明确许可**的组件或模板
- 核心原则：**Learn the idea, create your own expression.**（用别人的思路，做自己的表达）

### 🟡 YELLOW 黄灯：Check the License（必须检查）
- 遇到以下资源**必须先检查 License / Terms**：
  - GitHub repo、CodePen code、UI component、Font
  - Icon、Image、Illustration、Template、Framer template、Webflow cloneable、UI Kit
- 必须提醒两句话：
  - **Free ≠ Copyright Free（免费 ≠ 无版权）**
  - **Public ≠ Open Source（公开 ≠ 开源）**
- **检查四要点**：
  1. 这是什么许可（License）？
  2. 是否允许商用？
  3. 是否需要署名（Attribution）？
  4. 是否允许修改和再发布？

### 🔴 RED 红灯：Do Not Copy and Republish（禁止）
- **不要**：下载别人的完整网站，然后只替换 Name / Photo / Text / Logo / Colors
- **尤其不要直接复制**：Text、Photos、Illustrations、Logos、Videos、Music、Branding
- **也不要复制**：Proprietary code（专有代码）、未经许可的素材
- 核心原则：**Copy the idea, not the assets.**（复制思路，而不是照搬素材）

---

## 5. 课件中散见的其他硬性要求

| 出处 | 要求 |
|---|---|
| 观察原则（P7） | **Don't copy first. Observe first.** 先观察，再借鉴 |
| 四个借鉴层级（P8/P9） | Level 1 灵感（无需下载）、Level 2 元素（通常不需要）、Level 3 组件（可能需要）、**Level 4 模板（通常需要，且必须"明确许可后"才可 Clone/Fork 并替换成自己的内容）** |
| GitHub 模板（P22） | **必须检查**：README / License / Tech stack / 是否适合 GitHub Pages / 是否需要署名 / 是否允许修改和发布 |
| CodePen（P14） | 集成前须判断兼容性；**如需要，须检查许可/署名** |
| 组件库 Magic UI（P17） | 纯 HTML/CSS/JS 项目**不应直接复制粘贴**；应让 AI 判断是否兼容，**最好借鉴效果而非直接安装** |
| Aceternity UI（P16） | 很多效果依赖 React/Tailwind/Motion；对学生**最好借鉴效果而非直接安装** |
| 给 AI 的边界（P4/P33） | 明确约束：**不复制其文字、图片、品牌与源码**；给 AI 一个"分析任务"，而不是"照抄指令" |
| AI 使用顺序（P33） | Analyze reference → Identify what I like → Check compatibility → Propose a plan → **Then modify** |

---

## 6. 我（DeepWorks）在 V2 制作中的落实承诺

在 V2 及后续版本的**每一次制作**中，我将严格执行：

1. **只借设计思路，不搬素材**：只学习风格/布局/层级/留白/交互思路，所有文字、图片、品牌、视频、音乐、代码一律用本项目自有内容重新实现，绝不复制。
2. **素材来源可追溯**：任何引用的图标/图片/字体/组件/模板/代码，都必须能说明来源 URL、作者/版权方。
3. **先查许可再用（黄灯流程）**：遇到 GitHub/CodePen/组件库/字体/图标/模板，先核对 License 四要点（许可类型、可否商用、是否需署名、可否修改再发布）；**不明确则不用，改为自己重做。**
4. **红黄绿灯逐项判断**：每个借鉴对象都标注为 🟢/🟡/🔴，只有绿灯与已核验的黄灯才会进入成品。
5. **建立并维护素材许可台账**：见 `docs/V2-素材许可台账.md`，逐条登记，作为交付附件。
6. **交付前版权自检**：对照第 8 节逐条打勾，未通过不交付。
7. **过程留档**：所有制作过程、对话记录、代码、页面，继续保存在本项目文件夹（`docs/`、`outputs/`），便于交作业核对。

---

## 7. 建议的 V2 工作流（含版权关卡）

```
Find（找灵感/参考）
  → Analyze（先分析：它用了什么设计元素）
  → Select（选择要借鉴的点）
  → 🟡 CHECK LICENSE（黄灯关卡：核验许可四要点，登记台账）
  → Adapt（用"自己的内容"重新实现）
  → Integrate（整合进现有 HTML/CSS/JS）
  → Test（预览：桌面 + 移动端）
  → Personalize（个性化表达）
  → 🔴 FINAL CHECK（红灯自检 + 四句话底线）
```

---

## 8. 交付前版权自检清单（逐条打勾）

- [ ] 没有下载并替换别人的完整网站（未做"只换名字/照片/文字/Logo/颜色"的事）
- [ ] 没有复制任何第三方文字（Text）
- [ ] 没有复制任何第三方图片/插画/照片（Photos / Illustrations）
- [ ] 没有复制任何第三方 Logo / 品牌（Logos / Branding）
- [ ] 没有复制第三方视频/音乐（Videos / Music）
- [ ] 没有复制专有代码（Proprietary code）
- [ ] 所有引用的资源都在 `docs/V2-素材许可台账.md` 中登记，且许可明确
- [ ] 需署名的资源已按要求署名（若无可忽略）
- [ ] 每一处借鉴都符合"Copy the idea, not the assets."
- [ ] 四句话底线全部通过：Reference ≠ Copy / Public ≠ Open Source / Free ≠ Copyright Free / Copy the idea, not the assets.

---

## 附：课件四句原文（备查，勿改动）

> Reference ≠ Copy —— 参考不等于复制
> Public ≠ Open Source —— 公开不等于开源
> Free ≠ Copyright Free —— 免费不等于无版权
> Copy the idea, not the assets. —— 复制思路，而不是素材
