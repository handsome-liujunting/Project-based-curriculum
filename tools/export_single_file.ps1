param(
  [Parameter(Mandatory=$true)][string]$Src,
  [Parameter(Mandatory=$true)][string]$OutHtml,
  [string]$OutDir = ''
)

# ============================================================================
#  export_single_file.ps1 -- flatten the site into ONE self-contained .html
#
#  Inlines, auto-discovered (so adding a css/js file never needs an edit here):
#    * every <link rel="stylesheet" href="css/...">   (+ woff2 -> base64)
#    * every <script src="js/..."></script>
#    * every <img src="assets/...">                   -> base64 data URI
#    * the two OFL license texts, as <script type="text/plain"> blocks
#  then strips font <link rel="preload"> tags and refuses to write if any
#  local reference survives.
#
#  IMPORTANT: keep this file PURE ASCII. PowerShell 5.1 parses a .ps1 without
#  a BOM as ANSI/cp936, so Chinese text in here gets mis-decoded, and some
#  byte pairs swallow the following character -- which silently swallowed a
#  whole statement (the image inlining assignment) once. Comments are not
#  worth that risk. The V4+ZCOOL license texts are embedded at runtime, so
#  nothing Chinese needs to live in this file.
# ============================================================================

$ErrorActionPreference = 'Stop'
$src = (Resolve-Path -LiteralPath $Src).Path

function Read-Utf8([string]$p) {
  return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
}
function B64([string]$p) {
  return [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($p))
}
function Count-Matches([string]$text, [string]$pattern) {
  return ([regex]::Matches($text, $pattern)).Count
}

$html = Read-Utf8 (Join-Path $src 'index.html')

# --- inline images FIRST (body content, independent of css/js) --------------
#  Doing this before the css/js passes keeps it a plain string operation on
#  the file as read, which is the state the regex below was verified against.
$imgRefs = [regex]::Matches($html, '<img\s+([^>]*?)src="(assets/[^"]+)"([^>]*)>')
"img refs    : $($imgRefs.Count)"
foreach ($m in $imgRefs) {
  $rel = $m.Groups[2].Value
  $p = Join-Path $src ($rel -replace '/', '\')
  if (-not (Test-Path -LiteralPath $p)) { throw ('image not found: ' + $rel) }
  $ext = [System.IO.Path]::GetExtension($p).ToLower()
  switch ($ext) {
    '.jpg'  { $mime = 'image/jpeg' }
    '.jpeg' { $mime = 'image/jpeg' }
    '.png'  { $mime = 'image/png' }
    '.webp' { $mime = 'image/webp' }
    '.gif'  { $mime = 'image/gif' }
    default { throw ('unknown image type, add it here: ' + $rel) }
  }
  $uri = 'data:' + $mime + ';base64,' + (B64 $p)
  $html = $html.Replace($m.Value, '<img ' + $m.Groups[1].Value + 'src="' + $uri + '"' + $m.Groups[3].Value + '>')
}

# --- inline stylesheets ----------------------------------------------------
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

# --- inline scripts --------------------------------------------------------
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

# --- license texts ---------------------------------------------------------
$l1 = Read-Utf8 (Join-Path $src 'assets\fonts\OFL-Bangers.txt')
$l2 = Read-Utf8 (Join-Path $src 'assets\fonts\OFL-ZCOOL-KuaiLe.txt')
foreach ($l in @($l1, $l2)) {
  if ($l -match '</script') { throw 'license text contains </script, cannot embed inline' }
}

# --- strip preload links (fonts are already inlined as base64) -------------
$html = [regex]::Replace($html, '<link rel="preload"[^>]*>\s*', '')

# --- embed license texts before </body> -----------------------------------
$embed = '<script type="text/plain" id="of-license-bangers">' + "`n" + $l1 + "`n" + '</script>' + "`n" +
         '<script type="text/plain" id="of-license-zcool-kuaile">' + "`n" + $l2 + "`n" + '</script>' + "`n"
$idx = $html.LastIndexOf('</body>')
if ($idx -lt 0) { throw 'body close tag not found' }
$html = $html.Substring(0, $idx) + $embed + $html.Substring($idx)

# --- sanity: no leftover local sub-resource references ---------------------
$leftover = @()
foreach ($pat in @('href="css/', 'src="js/', 'href="assets/', 'src="assets/')) {
  if ($html.Contains($pat)) { $leftover += $pat }
}
if ($leftover.Count -gt 0) { throw ('leftover local reference in single file: ' + ($leftover -join ', ')) }

# --- sanity: every img must now be a data URI ------------------------------
$imgTotal = Count-Matches $html '<img\s'
$imgData  = Count-Matches $html 'src="data:image/'
if ($imgTotal -ne $imgData) { throw "image inlining mismatch: data=$imgData total=$imgTotal" }
if ($imgTotal -gt 0) { "images ok   : $imgData/$imgTotal as data URI" }

# --- write single file -----------------------------------------------------
$outDirPath = Split-Path -Parent $OutHtml
if ($outDirPath -ne '' -and -not (Test-Path -LiteralPath $outDirPath)) {
  New-Item -ItemType Directory -Path $outDirPath -Force | Out-Null
}
[System.IO.File]::WriteAllText($OutHtml, $html, (New-Object System.Text.UTF8Encoding($false)))

# --- optional folder copy --------------------------------------------------
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
