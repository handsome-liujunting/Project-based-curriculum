# =====================================================================
#  make_thumbs.ps1 -- PNG -> JPEG thumbnail (System.Drawing, no ImageMagick).
#
#  WHY: the homepage gains a "V1 -> V4" block; the four version shots are
#       1440x900 PNG (~150 KB each) which is too heavy to embed four times
#       in the page (and in the single-file export, where every byte is
#       base64-inflated by ~37%). Downscaling to a fixed width as JPEG keeps
#       the block small while staying readable.
#
#  USAGE
#    powershell -File tools\make_thumbs.ps1 -Items `
#      'outputs\shots\v1-hero.png|outputs\screenshots-v4\versions\thumb-v1.jpg'
#    (optional third field on an item = target width)
#
#  Script must stay pure ASCII (5002).
# =====================================================================
param(
  [Parameter(Mandatory=$true)][string[]]$Items,   # "src.png|out.jpg[|width]"
  [int]$Width = 880,
  [int]$Quality = 78
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
             Where-Object { $_.MimeType -eq 'image/jpeg' }
if (-not $jpegCodec) { throw 'no JPEG encoder available' }

function Save-Jpeg($bmp, [string]$path, [int]$quality) {
  $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Quality, [int]$quality)
  $bmp.Save($path, $jpegCodec, $ep)
  $ep.Dispose()
}

foreach ($it in $Items) {
  $f = $it -split '\|'
  if ($f.Count -lt 2) { "SKIP bad item: $it"; continue }
  $src = $f[0].Trim()
  $out = $f[1].Trim()
  $w = if ($f.Count -ge 3 -and $f[2].Trim() -ne '') { [int]$f[2].Trim() } else { $Width }

  if (-not (Test-Path -LiteralPath $src)) { "MISS $src"; continue }

  $outDir = Split-Path -Parent $out
  if ($outDir -ne '' -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
  }

  $img = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $src).Path)
  $h = [int][Math]::Round($img.Height * ($w / [double]$img.Width))

  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.DrawImage($img, 0, 0, $w, $h)
  $g.Dispose(); $img.Dispose()

  Save-Jpeg $bmp $out $Quality
  $bmp.Dispose()
  "  thumb $out  ${w}x${h}  q=$Quality  $((Get-Item -LiteralPath $out).Length) bytes"
}
"OK"
