# V4 截图索引（outputs/screenshots-v4）

本目录是**提交报告 a) 开发历史 与 b) 主要功能 的配图来源**
（作业要求原文：报告需含 a) 开发历史（版本 + 截图）b) 新增/修改的主要功能）。

旧的 V3.5 全套截图（14 张）保留在 `outputs/screenshots-v35/`，作为**改版前基线（Before）**，不改不删。

---

## 1. versions/ —— 版本首屏与整页

| 文件 | 尺寸 | 用途 | 对应要求 |
| --- | --- | --- | --- |
| `v1-hero.png` | 1440×900 | V1 首屏（浅色极简，LJT 圆标） | a) 开发历史 |
| `v2-hero.png` | 1440×900 | V2 首屏（卡片化排版 + 暖橙） | a) 开发历史 |
| `v3-hero.png` | 1440×900 | V3 首屏（美漫风整站重画） | a) 开发历史 |
| `v35-hero-before.png` | 1440×900 | **V3.5 首屏（改版前基线，冻结）** | a) / b) 对照 |
| `v4-hero.png` | 1440×900 | V4 首屏（导航多出「历程」） | a) / b) 对照 |
| `v4-feedback.png` | 1440×900 | 反馈弹窗（右下角「提个意见」） | b) 新增功能 |
| `v4-full.png` | 1440×6850 | **V4 整页**（首屏冻结后真实整页） | a) / b) 总览 |
| `v35-full-before.png` | 1440×5300 | **V3.5 整页（Before，同法拍摄）** | a) 对照 |
| `thumb-v1.jpg` … `thumb-v4.jpg` | 900×562 | 站点内嵌的 4 张版本缩略图 | b) 迭代区块素材 |

`thumb-v*.jpg` 与站内 `assets/img/iter-v*.jpg` **完全同源**（同一份文件复制而来），
报告里引用哪一份都不会出现「报告里的图」和「页面里的图」不一致。

## 2. 根目录 —— V4 新增区块

| 文件 | 尺寸 | 用途 | 对应要求 |
| --- | --- | --- | --- |
| `v4-iterations.png` | 1440×2000 | **首页「迭代历程」区块**（含顶栏与页脚，可看到导航中的「历程」） | b) 新增功能 |

---

## 3. 拍摄方法（可复现）

```powershell
# 站点根目录起服务（本机 8791）
tools\serve_site.ps1 -Root outputs -Port 8791

# 版本首屏 / 反馈弹窗 / 整页
.deepworks\tmp\run_shots_versions.ps1 -Task v4hero        # -> versions\v4-hero.png
.deepworks\tmp\run_shots_versions.ps1 -Task v4feedback    # -> versions\v4-feedback.png
.deepworks\tmp\run_shots_versions.ps1 -Task v4full        # -> versions\v4-full.png
.deepworks\tmp\run_shots_versions.ps1 -Task v35full       # -> versions\v35-full-before.png
.deepworks\tmp\run_shots_versions.ps1 -Task v4iter        # -> v4-iterations.png
```

### 3.1 为什么整页图要「冻结首屏」

`css/style.css` 第 169 行：`.hero { min-height: 90vh }`。
**首屏高度 = 视口高度的 90%**，所以用超高窗口拍整页时，首屏会被拉长到窗口高度的 90%——
`1440×6200` 的窗口里，首屏就占掉 5495px，整页图只能拍到首屏 + 下一屏，**并不是整页**。
（实测：视口 805px 时首屏 725px；视口 6105px 时首屏 5495px。）

因此整页图走 `make_shot_copy.ps1 -Mode full`：把 `.hero` 高度按真实 1440×900 视口固定成 725px，
再用 `1440×6850` 的窗口拍，得到的就是**真实整页**（实测文档高 6833px）。

### 3.2 为什么区块图要「只留一个区块」

`#iterations` 及其下方内容在整页里被前面的区块推得很靠下，直接按片段（`#iterations`）滚动拍摄
会落在空白区（实测得到纯色帧，判定为失败）。
所以区块图走 `make_shot_copy.ps1 -Mode iterations`：**隐藏除 `#iterations` 以外的所有区块**，
在 `1440×2000` 窗口里拍，得到「顶栏 + 迭代区块 + 页脚」的干净区块图，尺寸即区块真实高度。

### 3.3 临时副本位置

拍摄用的改版副本放在 `outputs\_work\shots\`（脚本 `make_shot_copy.ps1` 生成）：

* 服务根目录是 `outputs`，所以放在这里能被 http 访问；
* 路径含 `_work` 段，**不会出现在交付产物面板**，也已在 `.gitignore` 中排除（`outputs/_work/`）；
* 真实站点文件从未被改动——所有注入只发生在副本上。

### 3.4 其它口径

* 所有截图均走 http 渲染（`file://` 下自托管 woff2 字体不加载，字形会不对）；
* 一律加 `--force-prefers-reduced-motion`，让 `.reveal` 揭示动画直接到位（否则截到的是未显示的空白）；
* 预览真实视口为 1440×805；首屏图统一 1440×900。
