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
$css  = Read-Utf8 (Join-Path $src 'css\style.css')
$css2 = Read-Utf8 (Join-Path $src 'css\feedback.css')
$js   = Read-Utf8 (Join-Path $src 'js\main.js')
$js2  = Read-Utf8 (Join-Path $src 'js\feedback-config.js')
$js3  = Read-Utf8 (Join-Path $src 'js\feedback.js')

# --- fonts -> base64 data URIs ---
$b1 = B64 (Join-Path $src 'assets\fonts\bangers-latin.woff2')
$b2 = B64 (Join-Path $src 'assets\fonts\zcool-kuaile-subset.woff2')
$css = $css.Replace('url("../assets/fonts/bangers-latin.woff2")', 'url("data:font/woff2;base64,' + $b1 + '")')
$css = $css.Replace('url("../assets/fonts/zcool-kuaile-subset.woff2")', 'url("data:font/woff2;base64,' + $b2 + '")')
if ($css.Contains('assets/fonts/bangers-latin.woff2')) { throw 'bangers path not inlined' }
if ($css.Contains('assets/fonts/zcool-kuaile-subset.woff2')) { throw 'zcool path not inlined' }
if ($css2 -match 'url\(') { throw 'feedback.css unexpectedly references assets' }

# --- license texts ---
$l1 = Read-Utf8 (Join-Path $src 'assets\fonts\OFL-Bangers.txt')
$l2 = Read-Utf8 (Join-Path $src 'assets\fonts\OFL-ZCOOL-KuaiLe.txt')
foreach ($l in @($l1, $l2)) {
  if ($l -match '</script') { throw 'license text contains </script, cannot embed inline' }
}
foreach ($j in @($js, $js2, $js3)) {
  if ($j -match '</script') { throw 'script contains </script, cannot embed inline' }
}

# --- strip preload links, inline css/js ---
$html = [regex]::Replace($html, '<link rel="preload"[^>]*>\s*', '')

$pairs = @(
  ,@('<link rel="stylesheet" href="css/style.css" />',    ('<style>' + "`n" + $css + "`n" + '</style>'))
  ,@('<link rel="stylesheet" href="css/feedback.css" />', ('<style>' + "`n" + $css2 + "`n" + '</style>'))
  ,@('<script src="js/main.js"></script>',                ('<script>' + "`n" + $js + "`n" + '</script>'))
  ,@('<script src="js/feedback-config.js"></script>',     ('<script>' + "`n" + $js2 + "`n" + '</script>'))
  ,@('<script src="js/feedback.js"></script>',            ('<script>' + "`n" + $js3 + "`n" + '</script>'))
)
foreach ($p in $pairs) {
  if (-not $html.Contains($p[0])) { throw ('tag not found: ' + $p[0]) }
  $html = $html.Replace($p[0], $p[1])
}

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
