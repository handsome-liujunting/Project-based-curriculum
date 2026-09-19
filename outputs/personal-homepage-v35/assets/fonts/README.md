# 字体说明（assets/fonts）

本目录的字体用于 V3 的大标题展示字体。**已完整自托管，页面运行时零外部请求。**

## 清单

| 文件 | 用途 | 来源 | 授权 |
|---|---|---|---|
| `bangers-latin.woff2` | 拉丁字母 / 数字的漫画展示字体 | Google Fonts `Bangers` | SIL OFL 1.1（`OFL-Bangers.txt`） |
| `zcool-kuaile-subset.woff2` | 中文标题字体（站酷快乐体） | Google Fonts `ZCOOL KuaiLe` | SIL OFL 1.1（`OFL-ZCOOL-KuaiLe.txt`） |
| `OFL-Bangers.txt` | 授权全文（随字体分发） | — | — |
| `OFL-ZCOOL-KuaiLe.txt` | 授权全文（随字体分发） | — | — |

版权声明：
- Bangers — Copyright 2010 The Bangers Project Authors (https://github.com/googlefonts/bangers)
- ZCOOL KuaiLe — Copyright 2018 The ZCOOL KuaiLe Project Authors (https://github.com/googlefonts/zcool-kuaile)

两个字体的 OFL 授权均**未声明 Reserved Font Name**，因此允许子集化与再分发
（OFL 1.1 第 2、3、5 条）。本目录已随附授权全文，符合 OFL 的分发要求。

## 为什么要子集化

中文字体动辄 5–10 MB，无法直接用于静态页。这里使用 Google Fonts 的
`text=` 接口，仅请求**页面实际用到的 237 个字形**，产物仅 24 KB。

副作用：**子集是静态的**——如果之后在页面上新增了汉字，必须重新生成，
否则新字会回退到系统字体（视觉上会不一致）。

## 如何重新生成子集

> 前提：能访问 `fonts.googleapis.com`（本机 PowerShell 5.1 需先启用 TLS 1.2）

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
$root = '<仓库>/outputs/personal-homepage-v3'
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

> 注意：只替换 `assets/fonts/` 下的 woff2 文件即可，**`OFL-*.txt` 不要删除**，
> 那是 OFL 授权要求随字体分发的文件。
