# =====================================================================
#  crop_dark_band.ps1 -- crop the longest dark band out of a tall screenshot.
#
#  WHY THIS EXISTS
#    The V4 iteration section has an ink-black background, which makes it the
#    only full-width dark band in the page (the sticky topbar is dark too, but
#    only ~70 rows tall). Instead of measuring the section offset with a
#    probe copy and remembering the number -- which breaks every time the
#    page grows -- the section is found IN THE IMAGE: scan rows, mark a row
#    dark when most sampled pixels are, take the longest unbroken run, crop
#    it with a small margin.
#
#    This replaces the "#iterations fragment scroll" attempt, which came back
#    as a blank frame: a fragment scroll only works if the browser repaints
#    the target region, and in this headless flow it captured a flat area.
#    Cropping the full-page render is deterministic and needs no scroll.
#
#  USAGE
#    powershell -File tools\crop_dark_band.ps1 `
#      -Src outputs\screenshots-v4\versions\v4-full.png `
#      -Out outputs\screenshots-v4\iterations-section.png
#
#  The tool always prints EVERY dark band it found, so a wrong pick is
#  obvious from the console before anyone looks at the image.
#
#  -StripLeft is the important knob. Sampling the FULL row width fails for a
#  section that holds white cards: at a card row the cards cover ~90% of the
#  width, so the row is "not dark" and the black background never forms a
#  contiguous band. The page keeps the outer ~140px as pure section
#  background (sections are full-bleed, their content is max-width:1100
#  centred), so sampling only that left margin gives one unbroken run for the
#  whole section no matter what sits inside it. 0 = sample the full width.
#  Script must stay pure ASCII.
# =====================================================================
param(
  [Parameter(Mandatory=$true)][string]$Src,
  [Parameter(Mandatory=$true)][string]$Out,
  [int]$Thresh = 60,        # luminance below this counts as "dark"
  [double]$Frac = 0.6,      # share of sampled pixels that must be dark
  [int]$Margin = 26,        # extra rows kept above/below the band
  [int]$MinHeight = 240,    # ignore bands shorter than this (topbar, rules)
  [int]$StripLeft = 140     # sample x in [0, StripLeft); 0 = full width
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$srcPath = (Resolve-Path -LiteralPath $Src).Path
$bmp = [System.Drawing.Bitmap]::FromFile($srcPath)
"source      : $srcPath  ($($bmp.Width)x$($bmp.Height))"

$step = 8
$xMax = if ($StripLeft -gt 0) { [Math]::Min($StripLeft, $bmp.Width) } else { $bmp.Width }
"sampling    : x 0..$($xMax - 1) step $step  (full width: $($StripLeft -eq 0))"
$dark = New-Object bool[] $bmp.Height
for ($y = 0; $y -lt $bmp.Height; $y++) {
  $hit = 0; $n = 0
  for ($x = 0; $x -lt $xMax; $x += $step) {
    $c = $bmp.GetPixel($x, $y)
    $lum = 0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B
    if ($lum -lt $Thresh) { $hit++ }
    $n++
  }
  $dark[$y] = (($hit / $n) -ge $Frac)
}

# collect runs
$bands = @()
$start = -1
for ($y = 0; $y -le $bmp.Height; $y++) {
  $isDark = ($y -lt $bmp.Height) -and $dark[$y]
  if ($isDark -and $start -lt 0) { $start = $y }
  if ((-not $isDark) -and $start -ge 0) {
    $bands += [pscustomobject]@{ start = $start; end = $y - 1; height = $y - $start }
    $start = -1
  }
}

"dark bands  : $($bands.Count)"
foreach ($band in $bands) {
  $mark = if ($band.height -ge $MinHeight) { '  <-- candidate' } else { '' }
  "   y $($band.start) .. $($band.end)   height $($band.height)$mark"
}

$best = $bands | Where-Object { $_.height -ge $MinHeight } | Sort-Object -Property height -Descending | Select-Object -First 1
if (-not $best) { $bmp.Dispose(); throw "no dark band taller than $MinHeight rows found -- lower -MinHeight or -Frac" }

$top = [Math]::Max(0, $best.start - $Margin)
$bot = [Math]::Min($bmp.Height - 1, $best.end + $Margin)
$h = $bot - $top + 1
"picked      : y $top .. $bot  ($($bmp.Width)x$h)"

$outDir = Split-Path -Parent $Out
if ($outDir -ne '' -and -not (Test-Path -LiteralPath $outDir)) {
  New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$rect = New-Object System.Drawing.Rectangle 0, $top, $bmp.Width, $h
$crop = $bmp.Clone($rect, $bmp.PixelFormat)
$crop.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose()
$bmp.Dispose()

"OK          : $Out  ($((Get-Item -LiteralPath $Out).Length) bytes)"
