param(
  [Parameter(Mandatory=$true)][string]$Src,
  [Parameter(Mandatory=$true)][string]$OutHtml,
  [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$src = (Resolve-Path -LiteralPath $Src).Path

function Read-Utf8([string]$p) {
  return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
}
function B64([string]$p) {
  return [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($p))
}

$html = Read-Utf8 (Join-Path $src 'index.html')

# --- inline every stylesheet / script that index.html references --------------
# 自动发现，不再写死文件清单：以后新增 css/js 文件不需要改这个脚本。
# （曾经因为写死清单，新增 digital-twin.css/js 时漏内联，被下面的保险检查拦住）
$fontDir = Join-Path $src 'assets\fonts'
$woff2 = @()
if (Test-Path -LiteralPath $fontDir) {
  $woff2 = @(Get-ChildItem -LiteralPath $fontDir -File -Filter '*.woff2')
}

$styleRefs = [regex]::Matches($html, '<link rel="stylesheet" href="(css/[^"]+)"\s*/?>')
if ($styleRefs.Count -eq 0) { throw 'no stylesheet reference found in index.html' }
foreach ($m in $styleRefs) {
  $rel = $m.Groups[1].Value
  $p = Join-Path $src ($rel -replace '/', '\')
  if (-not (Test-Path -LiteralPath $p)) { throw ('stylesheet not found: ' + $rel) }
  $code = Read-Utf8 $p
  foreach ($f in $woff2) {
    $u = '../assets/fonts/' + $f.Name
    if ($code.Contains($u)) {
      $code = $code.Replace('url("' + $u + '")', 'url("data:font/woff2;base64,' + (B64 $f.FullName) + '")')
    }
  }
  if ($code -match 'url\(["'']?\.\./assets/fonts/') { throw ('font not inlined in ' + $rel) }
  $html = $html.Replace($m.Value, '<style>' + "`n" + $code + "`n" + '</style>')
}
"inlined css : $($styleRefs.Count)"

$scriptRefs = [regex]::Matches($html, '<script src="(js/[^"]+)"></script>')
if ($scriptRefs.Count -eq 0) { throw 'no script reference found in index.html' }
foreach ($m in $scriptRefs) {
  $rel = $m.Groups[1].Value
  $p = Join-Path $src ($rel -replace '/', '\')
  if (-not (Test-Path -LiteralPath $p)) { throw ('script not found: ' + $rel) }
  $code = Read-Utf8 $p
  if ($code -match '</script') { throw ('script contains </script, cannot embed: ' + $rel) }
  $html = $html.Replace($m.Value, '<script>' + "`n" + $code + "`n" + '</script>')
}
"inlined js  : $($scriptRefs.Count)"

# --- license texts ---
$l1 = Read-Utf8 (Join-Path $src 'assets\fonts\OFL-Bangers.txt')
$l2 = Read-Utf8 (Join-Path $src 'assets\fonts\OFL-ZCOOL-KuaiLe.txt')
foreach ($l in @($l1, $l2)) {
  if ($l -match '</script') { throw 'license text contains </script, cannot embed inline' }
}

# --- strip preload links (fonts are already inlined as base64) ---
$html = [regex]::Replace($html, '<link rel="preload"[^>]*>\s*', '')

# --- embed license texts before </body> ---
$embed = '<script type="text/plain" id="of-license-bangers">' + "`n" + $l1 + "`n" + '</script>' + "`n" +
         '<script type="text/plain" id="of-license-zcool-kuaile">' + "`n" + $l2 + "`n" + '</script>' + "`n"
$idx = $html.LastIndexOf('</body>')
if ($idx -lt 0) { throw 'body close tag not found' }
$html = $html.Substring(0, $idx) + $embed + $html.Substring($idx)

# --- sanity: no leftover local sub-resource references ---
if ($html -match 'href="css/' -or $html -match 'src="js/' -or $html -match 'href="assets/') {
  throw 'leftover local reference in single file'
}

# --- write single file ---
$outDirPath = Split-Path -Parent $OutHtml
if ($outDirPath -ne '' -and -not (Test-Path -LiteralPath $outDirPath)) {
  New-Item -ItemType Directory -Path $outDirPath -Force | Out-Null
}
[System.IO.File]::WriteAllText($OutHtml, $html, (New-Object System.Text.UTF8Encoding($false)))

# --- optional folder copy ---
if ($OutDir -ne '') {
  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  Copy-Item -Path (Join-Path $src '*') -Destination $OutDir -Recurse -Force
}

"OK"
"single-file : $OutHtml  ($((Get-Item -LiteralPath $OutHtml).Length) bytes)"
if ($OutDir -ne '') {
  "folder copy : $OutDir  ($((Get-ChildItem -LiteralPath $OutDir -Recurse -File).Count) files)"
}
