# 字体说明（assets/fonts）

本目录的字体用于页面的**中文与拉丁大标题展示字体**。**已完整自托管，页面运行时零外部请求。**

> 最近更新：V3.5（2026-09-20）—— 文案调整后重新生成了两份子集。
> V3 版本说明见 `outputs/personal-homepage-v3/assets/fonts/README.md`。

## 清单

| 文件 | 用途 | 来源 | 当前大小 | 授权 |
|---|---|---|---|---|
| `bangers-latin.woff2` | 拉丁字母 / 数字的漫画展示字体（57 个字形） | Google Fonts `Bangers` | 9 496 B | SIL OFL 1.1（`OFL-Bangers.txt`） |
| `zcool-kuaile-subset.woff2` | 中文标题字体 · 站酷快乐体（274 个字形） | Google Fonts `ZCOOL KuaiLe` | 28 352 B | SIL OFL 1.1（`OFL-ZCOOL-KuaiLe.txt`） |
| `OFL-Bangers.txt` | 授权全文（随字体分发） | — | 4 479 B | — |
| `OFL-ZCOOL-KuaiLe.txt` | 授权全文（随字体分发） | — | 4 398 B | — |

版权声明：

- Bangers — Copyright 2010 The Bangers Project Authors (<https://github.com/googlefonts/bangers>)
- ZCOOL KuaiLe — Copyright 2018 The ZCOOL KuaiLe Project Authors (<https://github.com/googlefonts/zcool-kuaile>)

两个字体的 OFL 授权均**未声明 Reserved Font Name**，因此允许子集化与再分发
（OFL 1.1 第 2、3、5 条）。本目录已随附授权全文，符合 OFL 的分发要求。

## 为什么要子集化

中文字体动辄 5–10 MB，无法直接用于静态页。这里使用 Google Fonts 的
`text=` 接口，仅请求**页面实际用到的 274 个字形**，产物仅 28 KB；
拉丁字体同理，只取 57 个字符。

**副作用（重要）**：子集是静态的 —— 如果之后在页面上**新增了汉字，必须重新生成**，
否则新字会回退到系统字体，视觉上会明显不一致。

## 一个容易踩的坑：JS 注入的文案

子集是从 `index.html` 的**可见文本**里提取字符的，但页面上有些展示字体文案
是脚本运行时才写进 DOM 的（例如动态生成的气泡文字）。
这些字**不在 HTML 源码里**，所以必须额外补进字符集，
否则会出现"个别字是系统字体"的情况。

因此重建脚本额外读取一个补充清单：`tools/extra_display.txt`。
以后新增这类"由 JS 注入、且使用展示字体"的文案时，
记得同步把新字补进这个文件，再重建子集。

> 说明：反馈表单的状态提示文字（如"收到啦，谢谢你的意见！"）用的是**正文字体**，
> 不是展示字体，因此不需要进子集 —— 无需为此调整 `extra_display.txt`。

## 如何重新生成子集（推荐做法）

仓库里已经脚本化，**改完文案跑一条命令即可**：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\resubset.ps1" `
  -Root "outputs\personal-homepage-v35" -ExtraFile "tools\extra_display.txt"
```

脚本会打印 `CJK chars: N` 与 `ASCII chars: M`，以及写出后的文件字节数。
对照下表可快速判断"子集是否真的跟着文案变了"：

| 版本节点 | 汉字数 | zcool-kuaile-subset.woff2 |
|---|---|---|
| V3.5 初版 | 284 | 29 464 B |
| 第二格改文案后 | 288 | 29 952 B |
| 台词 +3 条后 | 300 | 31 272 B |
| 删除前三条台词后 | 293 | 30 452 B |
| 删除整块"我的台词"后（当前） | 274 | 28 352 B |

> 若打印出来的汉字数与 **274** 相同、字节数也完全相同，说明文案没变，不用重建。

## 手工重建（不想用脚本时）

> 前提：能访问 `fonts.googleapis.com`（PowerShell 5.1 需先启用 TLS 1.2）

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
$root = '<仓库>/outputs/personal-homepage-v35'
$fdir = Join-Path $root 'assets\fonts'

# 1) 从 index.html 提取所有汉字 / 中文标点（先去掉注释和标签）
$html = Get-Content -LiteralPath (Join-Path $root 'index.html') -Raw -Encoding UTF8
$txt  = [regex]::Replace($html, '<!--.*?-->', ' ', 'Singleline')
$txt  = [regex]::Replace($txt,  '<[^>]+>', ' ')
$chars = $txt.ToCharArray() | Where-Object {
  $c = [int]$_
  ($c -ge 0x4E00 -and $c -le 0x9FFF) -or ($c -ge 0x3000 -and $c -le 0x303F) -or `
  ($c -ge 0xFF00 -and $c -le 0xFFEF) -or ($c -ge 0x2018 -and $c -le 0x201D) -or `
  $c -eq 0xB7 -or $c -eq 0x2026
}
$cjk = ($chars | Sort-Object -Unique) -join ''

# 2) 请求 CSS -> 拿到 woff2 地址 -> 下载
$u = "https://fonts.googleapis.com/css2?family=ZCOOL+KuaiLe&text=" +
     [System.Uri]::EscapeDataString($cjk) + "&display=swap"
$css = Invoke-WebRequest -Uri $u -UseBasicParsing -Headers @{ 'User-Agent' = $ua }
$src = [regex]::Match($css.Content, 'url\((https://fonts\.gstatic\.com/[^)]+)\)').Groups[1].Value
Invoke-WebRequest -Uri $src -OutFile (Join-Path $fdir 'zcool-kuaile-subset.woff2') `
  -UseBasicParsing -Headers @{ 'User-Agent' = $ua }
```

拉丁字体同理，把 `family` 换成 `Bangers`、`text` 换成需要的 ASCII 字符集即可。

## 重建之后还要做什么

1. 跑 `tools\verify_v35.ps1 -Root "outputs\personal-homepage-v35"`，确认 `FAIL count = 0`。
2. **重新导出单文件版**（它把字体以 base64 内联进去了，不同步就是旧的）：
   `tools\export_single_file.ps1`
3. 提交 git。

> 注意：只替换 `assets/fonts/` 下的 woff2 文件即可，**`OFL-*.txt` 不要删除**，
> 那是 OFL 授权要求随字体分发的文件。
