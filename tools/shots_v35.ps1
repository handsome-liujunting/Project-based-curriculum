# =====================================================================
# V3.5 screenshot line (pure ASCII script, safe for PowerShell 5.1)
#
# WHAT IT PRODUCES
#   01..07  desktop 1440x900 slices, one per section (cropped from ONE tall render)
#   08/09   feedback modal  (desktop 1440x900 / mobile 414x900)
#   10/11   twin chat modal (desktop 1440x900 / mobile 414x900)
#   12      the whole page in one tall image (1440xTallH)
#   13/14   guestbook board alone (desktop 1440x? / mobile 414x?) -- see below
#
# WHY 13/14 USE ?only=board INSTEAD OF A CROP
#   The board sits near the bottom of a 5282px-tall page, so a crop would inherit
#   every offset above it. Instead the page is opened as ?only=board, where an
#   injected rule hides the topbar, every section except #board, the foot ticker
#   and the footer, and flattens main's spacing. What is left IS the board, so the
#   shot can be taken on a normal-size window with no scrolling at all.
#   The render is deliberately taller than the board, then trimmed numerically:
#   Trim-ToSection walks up from the bottom looking for the last row that still
#   carries the section background, crops just past it, and shouts CLIPPED if that
#   row is the very last one (which would mean the form got cut off).
#
# WHY CROP FOR 01..07 AND NEVER SCROLL
#   With --headless=new --screenshot, any real scroll (window.scrollTo or a
#   fragment jump) leaves the captured surface UNPAINTED (uniform dark frames),
#   while the same URL without scrolling renders fine. So 01..07 come from ONE
#   tall render that contains the whole document, cropped with System.Drawing.
#
# TWO INJECTED HELPERS (into a TEMP COPY only; the shipped file is never touched)
#   a) force .reveal visible  -- the scroll-fade uses IntersectionObserver, whose
#      callbacks are unreliable under --virtual-time-budget; without this the
#      screenshot can catch elements at opacity 0 (i.e. blank sections).
#      Forcing it equals the "already faded in" state a human sees.
#   b) pin .hero to 725px when ?full=1 -- --window-size=1440,900 gives a real
#      viewport of 1440x805, so .hero{min-height:90vh} is ~725px there; in the
#      4400px-tall render 90vh would be ~3900px and would stretch the hero and
#      shift every section. Pinning keeps the tall layout identical to the real one.
#
# WHY ONE PROCESS + ONE PROFILE PER RENDER
#   A previous version looped 5 tall renders inside a single run and got nothing
#   but empty frames, while the very same command succeeded from its own process.
#   Cause: a still-running Edge instance owns the profile, so the next launch is
#   forwarded to it and --screenshot returns immediately with an unpainted frame.
#   Fix: every render is its own Edge process, the profile rotates (0,1,2), and
#   every profile is warmed up once and discarded (a brand-new profile paints
#   Edge's own first-run surface instead of the page).
#
# Offsets come from probe_v35.ps1 (same hero pin). Re-run the probe after any
# layout change and update $slices below.
# =====================================================================
param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$Edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
  [int]$TallH = 5400,
  # Generous render heights for the two board shots; both are trimmed afterwards.
  [int]$BoardDeskH = 1400,
  [int]$BoardMobH = 1700
)

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Drawing

$tmpBase  = Join-Path $env:TEMP 'opencode'
$work     = Join-Path $tmpBase 'v35shot'
$profBase = Join-Path $tmpBase 'edgeprofile-shot'
$pngTmp   = Join-Path $tmpBase 'shot-src'

# ---------------------------------------------------------------- prep
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null
Copy-Item -Path (Join-Path $Root '*') -Destination $work -Recurse -Force

if (Test-Path -LiteralPath $pngTmp) { Remove-Item -LiteralPath $pngTmp -Recurse -Force }
New-Item -ItemType Directory -Path $pngTmp -Force | Out-Null

$outAbs = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutDir))
if (-not (Test-Path -LiteralPath $outAbs)) { New-Item -ItemType Directory -Path $outAbs -Force | Out-Null }

# ---------------------------------------------------------------- helpers
$helper = '<script>(function(){' +
  'var css=".reveal{opacity:1 !important;transform:none !important;transition:none !important}";' +
  'var q=location.search||"";' +
  'if(/[?&]full=1/.test(q)){css+=".hero{min-height:725px !important}"}' +
  'if(/[?&]only=board/.test(q)){css+=' +
    '"html,body{margin:0 !important;padding:0 !important}"+' +
    '"body>*:not(#main):not(#probe){display:none !important}"+' +
    '"#main{margin:0 !important;padding:0 !important}"+' +
    '"#main>section:not(#board){display:none !important}"+' +
    '"#board{margin:0 !important;padding-top:40px !important;padding-bottom:40px !important}"}' +
  'var s=document.createElement("style");s.textContent=css;document.head.appendChild(s);' +
  'if(/[?&]demo=1/.test(q)){window.addEventListener("load",function(){' +
    'setTimeout(function(){var p=document.querySelectorAll(".dt-pick");' +
      'if(p[0]){p[0].click()}' +
      'setTimeout(function(){if(p[1]){p[1].click()}},1500);' +
    '},400);' +
  '});}' +
'})();</script>'

$idx  = Join-Path $work 'index.html'
$html = [System.IO.File]::ReadAllText($idx, [System.Text.Encoding]::UTF8)
if ($html -notmatch [regex]::Escape($helper)) { $html = $html.Replace('</body>', $helper + '</body>') }
[System.IO.File]::WriteAllText($idx, $html, (New-Object System.Text.UTF8Encoding($false)))

$base = 'file:///' + ($work -replace '\\', '/') + '/index.html'

function Get-Profile([int]$n) {
  $p = "$profBase-$n"
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
  return $p
}

function Test-Frame($path) {
  # A real render has no single colour covering >=85% of a coarse 40px sample grid.
  if (-not (Test-Path -LiteralPath $path)) { return $false }
  $b = [System.Drawing.Bitmap]::FromFile($path)
  $counts = @{}; $n = 0
  for ($y = 0; $y -lt $b.Height; $y += 40) {
    for ($x = 0; $x -lt $b.Width; $x += 40) {
      $c = $b.GetPixel($x, $y)
      $k = "$([int]($c.R / 16)),$([int]($c.G / 16)),$([int]($c.B / 16))"
      if ($counts.ContainsKey($k)) { $counts[$k]++ } else { $counts[$k] = 1 }
      $n++
    }
  }
  $b.Dispose()
  if ($n -eq 0) { return $false }
  $top = ($counts.Values | Measure-Object -Maximum).Maximum
  return (($top / $n) -lt 0.85)
}

function Trim-ToSection([string]$srcPath, [string]$dstPath) {
  # Cut the isolated ?only=board render down to the board's real bottom edge.
  # The board sits on .section--yellow, so the last row that still carries that
  # background IS the section's bottom border. Everything under it is page
  # background and gets removed, which keeps the shot tight without guessing a
  # height. If that row is the last row of the image the render was too short and
  # the form is cut off -- that is reported as CLIPPED, never hidden.
  $b = [System.Drawing.Bitmap]::FromFile($srcPath)
  $w = $b.Width; $h = $b.Height
  $last = -1
  for ($y = $h - 1; $y -ge 0; $y--) {
    $c = $b.GetPixel(6, $y)
    if (($c.R -gt 200) -and ($c.G -gt 150) -and ($c.B -lt 120)) { $last = $y; break }
  }
  if ($last -lt 0) {
    $b.Dispose()
    return [pscustomobject]@{ ok = $false; note = 'no yellow section background found'; h = 0 }
  }
  $clipped = ($last -ge ($h - 3))
  $cropH = [Math]::Min($h, $last + 13)
  if ($cropH -lt 200) { $cropH = [Math]::Min($h, 200) }
  $out = New-Object System.Drawing.Bitmap -ArgumentList $w, $cropH
  $g = [System.Drawing.Graphics]::FromImage($out)
  $dst = New-Object System.Drawing.Rectangle 0, 0, $w, $cropH
  $srcR = New-Object System.Drawing.Rectangle 0, 0, $w, $cropH
  $g.DrawImage($b, $dst, $srcR, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose(); $b.Dispose()
  $out.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose()
  $note = 'ok'
  if ($clipped) { $note = 'CLIPPED - re-render taller' }
  return [pscustomobject]@{ ok = (-not $clipped); note = $note; h = $cropH }
}

$renderLog = @()
function Render([string]$name, [string]$url, [int]$w, [int]$h) {
  $png = Join-Path $pngTmp $name
  for ($a = 1; $a -le 6; $a++) {
    $prof = Get-Profile (($a - 1) % 3)
    if (Test-Path -LiteralPath $png) { Remove-Item -LiteralPath $png -Force }
    & $Edge @(
      '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
      '--no-default-browser-check', '--disable-extensions',
      "--user-data-dir=$prof", '--force-device-scale-factor=1',
      '--virtual-time-budget=9000', "--window-size=$w,$h",
      "--screenshot=$png", $url
    ) 2>$null | Out-Null
    Start-Sleep -Milliseconds 600
    if (Test-Frame $png) {
      $len = (Get-Item -LiteralPath $png).Length
      $script:renderLog += [pscustomobject]@{ name = $name; try = $a; bytes = $len }
      return $len
    }
    "      (empty/unpainted frame, retry $a with profile $(($a) % 3))"
  }
  $script:renderLog += [pscustomobject]@{ name = $name; try = -1; bytes = -1 }
  return -1
}

# ---------------------------------------------------------------- 0) warm-up
# Each profile's FIRST launch paints Edge's own first-run surface (uniform dark).
# Warm all three up once and throw those frames away.
foreach ($p in @(0, 1, 2)) {
  $warm = Join-Path $pngTmp "warm-$p.png"
  $prof = Get-Profile $p
  & $Edge @(
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
    '--no-default-browser-check', '--disable-extensions',
    "--user-data-dir=$prof", '--force-device-scale-factor=1',
    '--virtual-time-budget=3000', '--window-size=1200,800',
    "--screenshot=$warm", $base
  ) 2>$null | Out-Null
  Start-Sleep -Milliseconds 500
  $sz = if (Test-Path -LiteralPath $warm) { (Get-Item -LiteralPath $warm).Length } else { -1 }
  "warm-up profile-$p : $sz bytes (discarded)"
  if (Test-Path -LiteralPath $warm) { Remove-Item -LiteralPath $warm -Force }
}
""

# ---------------------------------------------------------------- 1) renders
"base : $base"
"out  : $outAbs"
""
"render tall ($(1440)x$($TallH)) ..."
$tallBytes = Render 'full.png' "$base`?full=1" 1440 $TallH
"  tall = $tallBytes bytes"

"render feedback desktop ..."
$fbD = Render 'fb-desktop.png' "$base#feedback" 1440 900
"  feedback desktop = $fbD bytes"

"render feedback mobile ..."
$fbM = Render 'fb-mobile.png' "$base#feedback" 414 900
"  feedback mobile  = $fbM bytes"

"render twin chat desktop ..."
$twD = Render 'twin-desktop.png' "$base`?demo=1#twin-chat" 1440 900
"  twin chat desktop = $twD bytes"

"render twin chat mobile ..."
$twM = Render 'twin-mobile.png' "$base`?demo=1#twin-chat" 414 900
"  twin chat mobile  = $twM bytes"

"render board desktop (isolated ?only=board) ..."
$bdD = Render 'board-desktop.png' "$base`?only=board" 1440 $BoardDeskH
"  board desktop = $bdD bytes"

"render board mobile (isolated ?only=board) ..."
$bdM = Render 'board-mobile.png' "$base`?only=board" 414 $BoardMobH
"  board mobile  = $bdM bytes"

""

# ---------------------------------------------------------------- 2) crops
$tall = Join-Path $pngTmp 'full.png'
if (-not (Test-Path -LiteralPath $tall)) { "FATAL: tall render missing"; exit 1 }
$src = [System.Drawing.Image]::FromFile($tall)
"source bitmap : $($src.Width)x$($src.Height)"

# offsets measured by probe_v35.ps1 (hero pinned to 725px), re-measured after the
# guestbook section went in:
#   story 855 / skills 1692 / works 2326 / twin 2933 / contact 3459 / board 3978 /
#   footer 5001 / docH 5282
# 01..05 start 60px above their section (= breathing room). 06 is centred on its
# section instead, because "60px above contact" would land only 30px away from the
# bottom-aligned 07 and produce two near-identical images.
$slices = @(
  @{ n = '01-hero.png';    y = 0 },
  @{ n = '02-story.png';   y = 795 },
  @{ n = '03-skills.png';  y = 1632 },
  @{ n = '04-works.png';   y = 2266 },
  @{ n = '05-twin.png';    y = 2873 },
  @{ n = '06-contact.png'; y = 3269 },   # contact 3459..3978 centred in the frame
  @{ n = '07-footer.png';  y = 4382 }    # bottom-aligned (docH 5282 - 900): last screen
)
$ok = 0
foreach ($s in $slices) {
  if (($s.y + 900) -gt $src.Height) { "  SKIP $($s.n) (y=$($s.y) beyond source)"; continue }
  $bmp = New-Object System.Drawing.Bitmap 1440, 900
  $g   = [System.Drawing.Graphics]::FromImage($bmp)
  $dst = New-Object System.Drawing.Rectangle 0, 0, 1440, 900
  $srcR = New-Object System.Drawing.Rectangle 0, $s.y, 1440, 900
  $g.DrawImage($src, $dst, $srcR, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $out = Join-Path $outAbs $s.n
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  "  crop $($s.n)  y=$($s.y)  $((Get-Item -LiteralPath $out).Length) bytes"
  $ok++
}
$src.Dispose()

# ---------------------------------------------------------------- 3) copy renders
Copy-Item -LiteralPath $tall -Destination (Join-Path $outAbs '12-full-page.png') -Force
if (Test-Path -LiteralPath (Join-Path $pngTmp 'fb-desktop.png'))  { Copy-Item -LiteralPath (Join-Path $pngTmp 'fb-desktop.png')  -Destination (Join-Path $outAbs '08-feedback-desktop.png') -Force }
if (Test-Path -LiteralPath (Join-Path $pngTmp 'fb-mobile.png'))   { Copy-Item -LiteralPath (Join-Path $pngTmp 'fb-mobile.png')   -Destination (Join-Path $outAbs '09-feedback-mobile.png')  -Force }
if (Test-Path -LiteralPath (Join-Path $pngTmp 'twin-desktop.png')) { Copy-Item -LiteralPath (Join-Path $pngTmp 'twin-desktop.png') -Destination (Join-Path $outAbs '10-twin-chat-desktop.png') -Force }
if (Test-Path -LiteralPath (Join-Path $pngTmp 'twin-mobile.png'))  { Copy-Item -LiteralPath (Join-Path $pngTmp 'twin-mobile.png')  -Destination (Join-Path $outAbs '11-twin-chat-mobile.png')  -Force }

# 13/14: the board renders are deliberately taller than the section, so they get
# trimmed to the board's own bottom edge instead of a hand-guessed height.
foreach ($pair in @(
  @{ src = 'board-desktop.png'; dst = '13-board.png' },
  @{ src = 'board-mobile.png';  dst = '14-board-mobile.png' }
)) {
  $sp = Join-Path $pngTmp $pair.src
  if (-not (Test-Path -LiteralPath $sp)) { "  MISSING render: $($pair.src)"; continue }
  $dp = Join-Path $outAbs $pair.dst
  $r = Trim-ToSection $sp $dp
  $dim = 'n/a'
  if (Test-Path -LiteralPath $dp) {
    $bb = [System.Drawing.Bitmap]::FromFile($dp)
    $dim = "$($bb.Width)x$($bb.Height)"
    $bb.Dispose()
  }
  "  trim $($pair.dst) <- $($pair.src) : $($r.note)  $dim  $((Get-Item -LiteralPath $dp).Length) bytes"
}


# ---------------------------------------------------------------- 4) verify by statistics
# (the model writing this cannot look at images, so every shot is checked
#  numerically: size, dimensions, colour-bucket richness, dominant share)
""
"---- statistics (richness = distinct 16-level colour buckets on a 40px grid) ----"
$rows = @()
foreach ($f in (Get-ChildItem -LiteralPath $outAbs -Filter *.png | Sort-Object Name)) {
  $b = [System.Drawing.Bitmap]::FromFile($f.FullName)
  $counts = @{}; $n = 0
  for ($y = 0; $y -lt $b.Height; $y += 40) {
    for ($x = 0; $x -lt $b.Width; $x += 40) {
      $c = $b.GetPixel($x, $y)
      $k = "$([int]($c.R / 16)),$([int]($c.G / 16)),$([int]($c.B / 16))"
      if ($counts.ContainsKey($k)) { $counts[$k]++ } else { $counts[$k] = 1 }
      $n++
    }
  }
  $w = $b.Width; $h = $b.Height; $b.Dispose()
  $top = ($counts.Values | Measure-Object -Maximum).Maximum
  $share = $top / $n
  $verdict = 'ok'
  if ($share -ge 0.85 -or $counts.Count -lt 6) { $verdict = 'CHECK' }
  $rows += [pscustomobject]@{
    file     = $f.Name
    size     = "$($w)x$($h)"
    bytes    = $f.Length
    buckets  = $counts.Count
    dominant = ('{0:N2}' -f $share)
    verdict  = $verdict
  }
}
$rows | Format-Table -AutoSize | Out-String
$pngCount = (Get-ChildItem -LiteralPath $outAbs -Filter *.png).Count
"---- cropped $ok / $($slices.Count) slices; $pngCount png in $outAbs ----"
