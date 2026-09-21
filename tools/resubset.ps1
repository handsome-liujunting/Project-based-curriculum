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

# Google Fonts is flaky from this machine (frequent timeouts), so every request
# walks a mirror list until one answers. Mirrors serve the same backend/v22 and
# honour the same ?text= server-side subsetting, so coverage is identical.
$cssHosts = @(
  'https://fonts.googleapis.com',
  'https://fonts.loli.net',
  'https://fonts.font.im',
  'https://fonts.googleapis.cn'
)
# font binary hosts, used if the URL returned by the css host is unreachable
$binHosts = @(
  'https://fonts.gstatic.com',
  'https://gstatic.loli.net',
  'https://fonts.gstatic.font.im',
  'https://fonts.gstatic.cn'
)

function Get-CssUrl {
  param([string]$Family, [string]$Text)
  $q = "/css2?family=$Family&text=" + [System.Uri]::EscapeDataString($Text) + "&display=swap"
  $errs = @()
  foreach ($h in $cssHosts) {
    foreach ($attempt in 1..2) {
      try {
        $resp = Invoke-WebRequest -Uri ($h + $q) -UseBasicParsing -Headers @{ 'User-Agent' = $ua } -TimeoutSec 25
        $m = [regex]::Match($resp.Content, 'url\((https://[^)]+)\)')
        if ($m.Success) {
          Write-Host ("  css host ok : $h  (attempt $attempt)")
          return $m.Groups[1].Value
        }
        $errs += "$h : no woff2 url in css"
      } catch {
        $errs += "$h : " + $_.Exception.Message
      }
    }
  }
  throw ("all css hosts failed -> " + ($errs -join ' || '))
}

function Get-Woff2 {
  param([string]$Family, [string]$Text, [string]$Out)
  $u = Get-CssUrl -Family $Family -Text $Text
  $cands = @($u)
  foreach ($bh in $binHosts) {
    $cands += ([regex]::Replace($u, '^https://[^/]+', $bh))
  }
  $errs = @()
  foreach ($c in $cands) {
    foreach ($attempt in 1..2) {
      try {
        Invoke-WebRequest -Uri $c -OutFile $Out -UseBasicParsing -Headers @{ 'User-Agent' = $ua } -TimeoutSec 60
        $len = (Get-Item -LiteralPath $Out).Length
        if ($len -lt 512) { throw "suspiciously small ($len bytes)" }
        return "OK $Family  chars=$($Text.Length)  bytes=$len  via=$([regex]::Match($c,'^https://[^/]+').Value)"
      } catch {
        $errs += "$c : " + $_.Exception.Message
      }
    }
  }
  throw ("all font hosts failed for $Family -> " + ($errs -join ' || '))
}

"CJK chars: $($cjk.Length)"
"ASCII chars: $($ascii.Length)"
Get-Woff2 -Family 'ZCOOL+KuaiLe' -Text $cjk -Out (Join-Path $fdir 'zcool-kuaile-subset.woff2')
Get-Woff2 -Family 'Bangers' -Text $ascii -Out (Join-Path $fdir 'bangers-latin.woff2')
"---- files ----"
Get-ChildItem -LiteralPath $fdir | ForEach-Object { "$($_.Name)  $($_.Length)" }
