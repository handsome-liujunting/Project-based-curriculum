# Rebuild font subsets for V3.5 (script must stay pure ASCII).
#   display-font CJK chars = visible Chinese in index.html + extra_display.txt
#   (extra list covers text that is not in the HTML visible text, e.g. injected by js)
param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$ExtraFile
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'

$fdir = Join-Path $Root 'assets\fonts'
$htmlPath = Join-Path $Root 'index.html'

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$txt = [regex]::Replace($html, '<!--.*?-->', ' ', 'Singleline')
$txt = [regex]::Replace($txt, '<[^>]+>', ' ')
$extra = [System.IO.File]::ReadAllText($ExtraFile, [System.Text.Encoding]::UTF8)

$all = $txt + ' ' + $extra

# CJK ideographs + CJK punctuation + fullwidth forms + curly quotes
$chars = $all.ToCharArray() | Where-Object {
  $c = [int]$_
  ($c -ge 0x4E00 -and $c -le 0x9FFF) -or ($c -ge 0x3000 -and $c -le 0x303F) -or `
  ($c -ge 0xFF00 -and $c -le 0xFFEF) -or ($c -ge 0x2018 -and $c -le 0x201D) -or `
  $c -eq 0xB7 -or $c -eq 0x2026
}
$cjk = ($chars | Sort-Object -Unique) -join ''

# latin + digits + halfwidth symbols
$asciiChars = $all.ToCharArray() | Where-Object { $ac = [int]$_; $ac -ge 32 -and $ac -le 126 }
$ascii = ($asciiChars | Sort-Object -Unique) -join ''

function Get-Woff2 {
  param([string]$Family, [string]$Text, [string]$Out)
  $u = "https://fonts.googleapis.com/css2?family=$Family&text=" + [System.Uri]::EscapeDataString($Text) + "&display=swap"
  $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -Headers @{ 'User-Agent' = $ua } -TimeoutSec 30
  $m = [regex]::Match($resp.Content, 'url\((https://fonts\.gstatic\.com/[^)]+)\)')
  if (-not $m.Success) { throw "no woff2 url for $Family" }
  Invoke-WebRequest -Uri $m.Groups[1].Value -OutFile $Out -UseBasicParsing -Headers @{ 'User-Agent' = $ua } -TimeoutSec 90
  $len = (Get-Item -LiteralPath $Out).Length
  return "OK $Family  chars=$($Text.Length)  bytes=$len"
}

"CJK chars: $($cjk.Length)"
"ASCII chars: $($ascii.Length)"
Get-Woff2 -Family 'ZCOOL+KuaiLe' -Text $cjk -Out (Join-Path $fdir 'zcool-kuaile-subset.woff2')
Get-Woff2 -Family 'Bangers' -Text $ascii -Out (Join-Path $fdir 'bangers-latin.woff2')
"---- files ----"
Get-ChildItem -LiteralPath $fdir | ForEach-Object { "$($_.Name)  $($_.Length)" }
