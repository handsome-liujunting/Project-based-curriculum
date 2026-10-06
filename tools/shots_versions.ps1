# =====================================================================
#  shots_versions.ps1 -- render ONE viewport-sized screenshot per page.
#
#  WHY THIS EXISTS
#    The V4 round needs a "same viewport, different version" series:
#    V1 / V2 / V3 / V4 all opened in the SAME 1440x900 window, so the four
#    images can be compared side by side (and reused as Before/After pairs).
#    shots_v35.ps1 cannot do this: it renders one tall document and crops
#    fixed offsets, which only works for the CURRENT version.
#
#  HOW IT WORKS
#    * pages are served over http://127.0.0.1 (never file://) so that
#      self-hosted woff2 fonts actually load -- file:// blocks them and the
#      comparison would silently fall back to system fonts
#    * EVERY page in the series fades its content in with .reveal (V2 puts
#      .reveal on the hero itself, V3 guards it behind html.js). In a
#      headless paint the observer never fires for most of them, so the
#      frame comes back with the content still at opacity:0.
#      Fixed with the browser's own reduced-motion switch instead of
#      injecting HTML: every version implements that path
#      (@media prefers-reduced-motion + the matchMedia branch in main.js),
#      so the visible result is the page's own intended state.
#      Measured on V2: 25/25 .reveal elements revealed with the flag vs 7/25
#      without it.
#    * every render is its own Edge process with a rotating profile, warmed
#      up once and discarded -- the fix for the "unpainted / empty frame"
#      failure documented in shots_v35.ps1
#    * every frame is checked numerically. A BLANK frame is a single flat
#      colour (ratio ~1.00, 1 colour). A real page can still be very airy:
#      V2 is a warm-white layout with an orange accent and legitimately
#      reaches ~0.90 on one colour, so the flat-colour limit is 0.97 and a
#      frame must also show at least a few distinct colours.
#      The measured ratio/colour count is printed for every shot, so a bad
#      frame can be judged from the console without opening the image.
#
#  USAGE (start the server first -- see the header of serve_site.ps1)
#    Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy',
#      'Bypass','-File','tools\serve_site.ps1','-Root','outputs','-Port','8791'
#    powershell -File tools\shots_versions.ps1 `
#      -BaseUrl http://127.0.0.1:8791 -OutDir outputs\screenshots-v4\versions `
#      -Items 'v1=personal-homepage/index.html','v2=personal-homepage-v2/index.html'
#
#  NOTE: "-Items a,b,c" through `powershell -File` collapses the array into
#  one comma-joined string. Call it with & from a wrapper .ps1 instead.
#
#  Script must stay pure ASCII (5002).
# =====================================================================
param(
  [Parameter(Mandatory=$true)][string]$BaseUrl,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [Parameter(Mandatory=$true)][string[]]$Items,   # each entry: "name=relative/path.html"
  [string]$Edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
  [int]$Width = 1440,
  [int]$Height = 900,
  [double]$MaxFlat = 0.97,   # a blank frame is ~1.00; V2 is ~0.90 and is fine
  [int]$MinColours = 6       # distinct colours on the 40px grid
)

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Drawing

$tmpBase  = Join-Path $env:TEMP 'opencode'
$shotDir  = Join-Path $tmpBase 'vershot'
$profBase = Join-Path $tmpBase 'edgeprofile-ver'

if (-not (Test-Path -LiteralPath $shotDir)) { New-Item -ItemType Directory -Path $shotDir -Force | Out-Null }
if (-not (Test-Path -LiteralPath $OutDir))  { New-Item -ItemType Directory -Path $OutDir  -Force | Out-Null }
$outAbs = (Resolve-Path -LiteralPath $OutDir).Path

function Get-Profile([int]$n) {
  $p = "$profBase-$n"
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
  return $p
}

function Measure-Frame($path) {
  # Returns @{ ok; ratio; colours }. Blank/unpainted frames are one flat colour.
  if (-not (Test-Path -LiteralPath $path)) { return @{ ok = $false; ratio = 1.0; colours = 0 } }
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
  if ($n -eq 0) { return @{ ok = $false; ratio = 1.0; colours = 0 } }
  $top   = ($counts.Values | Measure-Object -Maximum).Maximum
  $ratio = $top / $n
  $ok    = (($ratio -lt $MaxFlat) -and ($counts.Count -ge $MinColours))
  return @{ ok = $ok; ratio = $ratio; colours = $counts.Count }
}

function Render([string]$name, [string]$url, [int]$w, [int]$h) {
  $png = Join-Path $shotDir $name
  for ($a = 1; $a -le 6; $a++) {
    $prof = Get-Profile (($a - 1) % 3)
    if (Test-Path -LiteralPath $png) { Remove-Item -LiteralPath $png -Force }
    & $Edge @(
      '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
      '--no-default-browser-check', '--disable-extensions',
      '--force-prefers-reduced-motion',
      "--user-data-dir=$prof", '--force-device-scale-factor=1',
      '--virtual-time-budget=9000', "--window-size=$w,$h",
      "--screenshot=$png", $url
    ) 2>$null | Out-Null
    Start-Sleep -Milliseconds 600
    $m = Measure-Frame $png
    if ($m.ok) { return @{ bytes = (Get-Item -LiteralPath $png).Length; ratio = $m.ratio; colours = $m.colours } }
    "      (bad frame ratio=$([math]::Round($m.ratio,3)) colours=$($m.colours), retry $a)"
  }
  return @{ bytes = -1; ratio = 1.0; colours = 0 }
}

# --------------------------------------------------------------- server check
# The server is rooted above the version folders, so "/" is a 404 by design.
# Probe a file that must exist instead: the first item of this very run.
$probe = "$BaseUrl/" + (($Items[0] -split '=', 2)[1].Trim().TrimStart('/'))
try {
  $r = Invoke-WebRequest -Uri $probe -UseBasicParsing -TimeoutSec 15
  "server ok : $probe  status=$($r.StatusCode) bytes=$($r.RawContentLength)"
} catch {
  "FATAL: no server at $probe -- start tools\serve_site.ps1 first"
  "       $($_.Exception.Message)"
  exit 1
}

# --------------------------------------------------------------- warm up
foreach ($p in @(0, 1, 2)) {
  $warm = Join-Path $shotDir "warm-$p.png"
  $prof = Get-Profile $p
  & $Edge @(
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
    '--no-default-browser-check', '--disable-extensions',
    '--force-prefers-reduced-motion',
    "--user-data-dir=$prof", '--force-device-scale-factor=1',
    '--virtual-time-budget=3000', '--window-size=1200,800',
    "--screenshot=$warm", $probe
  ) 2>$null | Out-Null
  Start-Sleep -Milliseconds 500
  $sz = if (Test-Path -LiteralPath $warm) { (Get-Item -LiteralPath $warm).Length } else { -1 }
  "warm-up profile-$p : $sz bytes (discarded)"
  if (Test-Path -LiteralPath $warm) { Remove-Item -LiteralPath $warm -Force }
}
""

# --------------------------------------------------------------- renders
$rows = @()
foreach ($it in $Items) {
  $kv = $it -split '=', 2
  if ($kv.Count -ne 2) { "SKIP bad item: $it"; continue }
  $name = $kv[0].Trim()
  $rel  = $kv[1].Trim().TrimStart('/')
  $url  = "$BaseUrl/$rel"

  $res = Render "$name.png" $url $Width $Height
  $src = Join-Path $shotDir "$name.png"
  $dst = Join-Path $outAbs "$name.png"
  $dim = 'n/a'
  if ($res.bytes -gt 0) {
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $b = [System.Drawing.Bitmap]::FromFile($dst)
    $dim = "$($b.Width)x$($b.Height)"
    $b.Dispose()
    "  shot $name.png  $dim  $((Get-Item -LiteralPath $dst).Length) bytes  flat=$([math]::Round($res.ratio,3)) colours=$($res.colours)"
  } else {
    "  FAIL $name -> could not render a non-empty frame"
  }
  $rows += [pscustomobject]@{
    name = $name; url = $rel; bytes = $res.bytes; size = $dim
    flat = [math]::Round($res.ratio, 3); colours = $res.colours
  }
}

""
"---- summary ----"
$rows | Format-Table -AutoSize | Out-String
