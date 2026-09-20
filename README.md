# 个人主页（V3.5）

刘俊廷的个人主页 —— 课程作业「基于项目的学习」系列成果之一。

**线上地址**：https://handsome-liujunting.github.io/Project-based-curriculum/

这版在原设计之上做了两件事：**接上反馈后台**、**发布到 GitHub Pages**。
页面本身的设计（配色、排版、动效、截图）与 V3 保持一致，没有重做。

---

## 站点包含什么

| 区块 | 内容 |
|---|---|
| 首屏 | 姓名、专业、一句话定位、天际线背景 |
| 关于我 | 简介 + 课堂之外的爱好 |
| 技能 | 分组标签 |
| 数字分身 | 预设问答的本地对话（零联网、无 AI 接口） |
| 联系 | 邮箱与所在地 |
| 反馈 | 右下角「提个意见」按钮 → 弹窗表单 → 存进后台 |

数字分身是**预设问答**：所有回答都写在 `js/digital-twin.js` 里，点开来回聊都不产生任何网络请求。

---

## 目录结构

```
/                      ← 仓库根 = GitHub Pages 发布根
├── index.html         ← 站点主页（源码在 outputs/personal-homepage-v35/）
├── css/               ← style.css、feedback.css、digital-twin.css
├── js/                ← main.js、feedback-config.js、feedback.js、digital-twin.js
├── assets/fonts/      ← 两个字体子集 + OFL 授权全文 + 说明
├── outputs/           ← 各版本源码与截图（V1 / V2 / V3 / V3.5），不参与发布
├── docs/              ← 制作文档、后台接入说明、发布检查清单、素材台账
├── tools/             ← 校验 / 导出 / 同步 / 自检脚本
└── uploads/           ← 课件与参考素材（不入库）
```

历史版本保留在 `outputs/` 里，方便对照与回滚；根目录只放当前要发布的那一份。

---

## 反馈功能怎么工作的

```
访客填表 → fetch POST → Supabase PostgREST (/rest/v1/feedback) → feedback 表
```

- 数据库 **开启 RLS**，只有一条 INSERT 策略（`anon` 与 `authenticated` 都只能插入）；
  **没有**任何 select / update / delete 策略 —— 所以访客提交的反馈，除站点作者外没人能读到。
- 前端只用 **publishable key**（旧称 anon key），它本来就可以公开。
  **secret / service_role key 与数据库密码永不进前端、也不进仓库。**
- 看反馈走 Supabase 控制台（Table Editor），不在页面上开读取入口。

建表脚本：`docs/V3.5-建表与RLS.sql`
接入步骤：`docs/V3.5-反馈后台接入说明.md`

> 尚未接入时页面会**明说**「后台还没配置好」，不会假装提交成功。

---

## 本地预览

```powershell
# 起一个本地静态服务（端口 8123），然后浏览器打开 http://127.0.0.1:8123/
powershell -NoProfile -ExecutionPolicy Bypass -File tools\serve_v35.ps1
```

也可以直接打开 `outputs/personal-homepage-v35-standalone/index.html`（单文件版，双击即看）。

---

## 校验与自检

```powershell
# 1) 站点结构 / 资源存在性 / id 唯一 / JS 与 HTML 契约 / 外链 / 密钥扫描
powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify_v35.ps1 -Root "outputs\personal-homepage-v35"

# 2) 根目录再校验一次（站点源码同步后必须跑，-SiteOnly 只扫站点文件）
powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify_v35.ps1 -Root "." -SiteOnly

# 3) 接好 Supabase 之后：一条命令验收反馈链路
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check_feedback.ps1 -Post
```

第 3 条会检查配置形状、确认匿名读不到数据、插入一条带唯一标记的测试行，
并打印该标记与清理 SQL —— 按课件要求，**标记能在 Table Editor 里找到才算验收通过**。

---

## 文档

| 文件 | 内容 |
|---|---|
| `docs/V3.5-制作流程与记录.md` | 制作流程、文案逐字记录、缺陷修复、课件逐条对照与验收证据 |
| `docs/V3.5-反馈后台接入说明.md` | Supabase 接入六步、自测、报错对照表、安全红线 |
| `docs/V3.5-发布检查清单.md` | 发布前检查、逐屏 18 项、上线信息与回滚 |
| `docs/V3.5-建表与RLS.sql` | 建表 + 行级安全策略（可直接粘进 SQL Editor） |
| `docs/V3.5-素材许可台账.md` | 素材来源与许可登记 |

---

## 素材与许可

- 字体：**ZCOOL KuaiLe**（站酷快乐体）、**Bangers** —— 均为 OFL 授权，
  授权全文见 `assets/fonts/`。
- 参考了同系列课件的**做法与结构**，未使用其品牌名、标志、角色形象、插画或原文案。
