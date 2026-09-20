# ============================================================================
#  sync_site.ps1  --  Sync the site source to the publish root (repo root).
#
#  Why: GitHub Pages serves from the repo root (or /docs). This script copies
#       the working source tree to the root so the repo stays publishable.
#
#  Usage:
#     powershell -NoProfile -ExecutionPolicy Bypass -File tools\sync_site.ps1 `
#       -Src "outputs\personal-homepage-v35" -Dst "."
#
#  Notes (script must stay pure ASCII):
#   * Only copies: index.html, css\, js\, assets\  (nothing else is published)
#   * Never deletes anything. If the destination has extra files that are NOT
#     in the source, they are listed as warnings so you can decide manually.
#   * Prints a size table and then runs the verification script on the target.
# ============================================================================
param(
  [Parameter(Mandatory=$true)][string]$Src,
  [string]$Dst = ".",
  [string]$Verify = "tools\verify_v35.ps1"
)

$ErrorActionPreference = 'Stop'

function Say($s) { Write-Output $s }

$srcFull = (Resolve-Path -LiteralPath $Src).Path
$dstFull = (Resolve-Path -LiteralPath $Dst).Path

if ($srcFull -eq $dstFull) { throw "Src and Dst are the same folder: $srcFull" }

Say "===== sync : $srcFull"
Say "=====   ->  $dstFull"
Say ""

# Extension point names that are allowed to be missing in the source.
$items = @(
  @{ Rel = 'index.html';    Dir = $false },
  @{ Rel = 'css';           Dir = $true  },
  @{ Rel = 'js';            Dir = $true  },
  @{ Rel = 'assets';        Dir = $true  }
)

$copied = 0
foreach ($it in $items) {
  $s = Join-Path $srcFull $it.Rel
  $d = Join-Path $dstFull $it.Rel
  if (-not (Test-Path -LiteralPath $s)) { Say "  SKIP $($it.Rel)  (not in source)"; continue }
  if ($it.Dir) {
    # copy the CONTENTS of the folder (never nest a folder inside itself)
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    Copy-Item -Path (Join-Path $s '*') -Destination $d -Recurse -Force
  } else {
    Copy-Item -LiteralPath $s -Destination $d -Force
  }
  Say "  ok   $($it.Rel)"
  $copied++
}

Say ""
Say "===== copied $copied item(s); now listing published files ====="
foreach ($it in $items) {
  $d = Join-Path $dstFull $it.Rel
  if (-not (Test-Path -LiteralPath $d)) { continue }
  Get-ChildItem -LiteralPath $d -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($dstFull.Length).TrimStart('\')
    Say ("  {0,-46} {1,8} bytes" -f $rel, $_.Length)
  }
}

# --- stale-file warnings: what exists at the destination but not in the source
Say ""
Say "===== stale check (destination files not present in source) ====="
$stale = @()
foreach ($it in $items) {
  $d = Join-Path $dstFull $it.Rel
  $s = Join-Path $srcFull $it.Rel
  if (-not (Test-Path -LiteralPath $d)) { continue }
  if (-not (Test-Path -LiteralPath $s)) { continue }
  $dFiles = @(Get-ChildItem -LiteralPath $d -Recurse -File -ErrorAction SilentlyContinue)
  foreach ($f in $dFiles) {
    $rel = $f.FullName.Substring($dstFull.Length).TrimStart('\')
    $inSrc = Join-Path $srcFull $rel
    if (-not (Test-Path -LiteralPath $inSrc)) { $stale += $rel }
  }
}
if ($stale.Count -eq 0) { Say "  ok  no stale files (destination matches source)" }
else {
  $stale | ForEach-Object { Say "  WARN stale: $_" }
  Say "  -> these were NOT deleted. Remove them manually if they should be gone."
}

# --- verify the published copy
Say ""
if (Test-Path -LiteralPath $Verify) {
  Say "===== verifying published copy with $Verify (-SiteOnly) ====="
  & powershell -NoProfile -ExecutionPolicy Bypass -File $Verify -Root $dstFull -SiteOnly
} else {
  Say "WARN verify script not found: $Verify (skipped)"
}
