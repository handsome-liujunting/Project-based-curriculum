# =============================================================================
#  V3.5 feedback backend self-check  (courseware: verify it really landed)
#
#  Why this exists:
#    The page saying "success" is NOT proof (see courseware p.28).
#    This script talks to your Supabase project the same way a visitor does --
#    with the publishable key only -- and checks two things that actually matter:
#      1) an anonymous visitor CANNOT read existing feedback (RLS is on)
#      2) a clearly marked test row CAN be inserted (the write path works)
#
#  It never asks for, prints, or stores a secret key / database password.
#
#  Usage:
#    powershell -NoProfile -ExecutionPolicy Bypass -File tools\check_feedback.ps1
#    powershell ... -File tools\check_feedback.ps1 -Post            (also insert a test row)
#    powershell ... -File tools\check_feedback.ps1 -Root outputs\personal-homepage-v35
#
#  ASCII-only output on purpose (PowerShell 5.1 console encoding).
# =============================================================================
param(
  [string]$Root = "outputs\personal-homepage-v35",
  [switch]$Post,
  [string]$Marker = "",
  [int]$TimeoutSec = 25,
  # Self-test / non-Supabase backend escape hatch (see section 10 of the setup guide).
  # Default is strict: only https://<ref>.supabase.co is accepted.
  [switch]$AllowAnyHost
)
$ErrorActionPreference = 'Continue'
$script:fail = 0

function Say([string]$t) { Write-Output $t }

# Read the JSON body of a failed web request.
# PS 5.1 detail: Invoke-WebRequest already consumed the response stream, so the
# body lives in $_.ErrorDetails.Message; the stream fallback only works sometimes.
function Get-ErrBody($ex) {
  try {
    if ($ex.ErrorDetails -and $ex.ErrorDetails.Message) { return [string]$ex.ErrorDetails.Message }
  } catch { }
  try {
    $rs = $ex.Exception.Response.GetResponseStream()
    if (-not $rs) { return '' }
    $sr = New-Object System.IO.StreamReader($rs)
    $t = $sr.ReadToEnd()
    $sr.Close()
    return $t
  } catch { return '' }
}

$cfgPath = Join-Path $Root 'js\feedback-config.js'
Say "== V3.5 feedback backend self-check =="
Say ("config: " + $cfgPath)

if (-not (Test-Path -LiteralPath $cfgPath)) {
  Say "FAIL  config file not found"
  exit 1
}
$src = [System.IO.File]::ReadAllText($cfgPath, [System.Text.Encoding]::UTF8)

# ---- strip comments so comment text can never satisfy the checks ----
# NOTE: do NOT strip "//" everywhere -- that would eat the // inside "https://...".
# Only whole-line comments are removed, plus /* */ blocks.
$code = [regex]::Replace($src, '(?s)/\*.*?\*/', '')
$keep = @()
foreach ($ln in ($code -split "`r?`n")) {
  if ($ln.TrimStart().StartsWith('//')) { continue }
  $keep += $ln
}
$code = $keep -join "`n"

$url = [regex]::Match($code, 'url\s*:\s*"([^"]*)"').Groups[1].Value.Trim()
$key = [regex]::Match($code, 'anonKey\s*:\s*"([^"]*)"').Groups[1].Value.Trim()
$tbl = [regex]::Match($code, 'table\s*:\s*"([^"]*)"').Groups[1].Value.Trim()
$ver = [regex]::Match($code, 'siteVersion\s*:\s*"([^"]*)"').Groups[1].Value.Trim()
if (-not $tbl) { $tbl = 'feedback' }
if (-not $ver) { $ver = 'unknown' }

# ---- 1) url ----
$urlStrict = $url -match '^https://[A-Za-z0-9\-]+\.supabase\.co$'
$urlLoose  = $AllowAnyHost -and $url -match '^https?://[A-Za-z0-9\-\.]+(:\d+)?$'
if ($url -and $urlStrict) {
  Say ("PASS  [1/5] project url ....... " + $url)
} elseif ($urlLoose) {
  Say ("PASS  [1/5] endpoint (loose) .. " + $url + "   NOTE: -AllowAnyHost was used")
} else {
  Say ("FAIL  [1/5] project url ....... '" + $url + "'  (expected https://<ref>.supabase.co, no trailing slash)")
  $script:fail++
}

# ---- 2) key shape (masked) ----
$masked = ''
if ($key.Length -gt 18) { $masked = $key.Substring(0, 18) + '...' + $key.Substring($key.Length - 4) }
$keyOk = $false
if ($key -match '^sb_publishable_[A-Za-z0-9_\-]+$') { $keyOk = $true }
elseif ($key -match '^eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+$') { $keyOk = $true }
if ($keyOk) {
  Say ("PASS  [2/5] publishable key ... " + $masked)
} else {
  Say ("FAIL  [2/5] publishable key ... '" + $masked + "'  (expected sb_publishable_... or an eyJ... JWT)")
  $script:fail++
}
if ($key -match '(?i)service_role|secret') {
  Say "FAIL  [2b]  the value looks like a SECRET key -- never put that in the front end"
  $script:fail++
}

if ($script:fail -gt 0) {
  Say ""
  Say "Stopped before any network call. Fill js/feedback-config.js first"
  Say "(see section 4 of the V3.5 setup guide in docs/)."
  exit 1
}

$base = $url.TrimEnd('/')
$rest = $base + '/rest/v1/' + $tbl
$headers = @{
  'apikey'        = $key
  'Authorization' = 'Bearer ' + $key
  'Accept'        = 'application/json'
}

# ---- 3) reachability + anonymous read must be blocked ----
$readOk = $false
$readLeak = $false
try {
  $r = Invoke-WebRequest -Uri ($rest + '?select=id&limit=1') -Headers $headers -Method Get -TimeoutSec $TimeoutSec -UseBasicParsing
  $body = $r.Content.Trim()
  if ($r.StatusCode -eq 200 -and ($body -eq '[]' -or $body -eq '')) {
    $readOk = $true
    Say "PASS  [3/5] anon read blocked .. returned [] (RLS is on, visitors cannot read feedback)"
  } else {
    $readLeak = $true
    Say ("FAIL  [3/5] anon read blocked .. got data back: " + $body.Substring(0, [Math]::Min(120, $body.Length)))
    Say "      RLS is NOT protecting the table. Re-run section 2 of the V3.5 SQL file in docs/"
    $script:fail++
  }
} catch {
  $status = 0
  if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
  $errBody = Get-ErrBody $_
  # Two designs both count as "visitors cannot read feedback":
  #   a) RLS only (Supabase default grants kept) -> HTTP 200 with []
  #   b) RLS + revoke select (our SQL does this) -> HTTP 401/403 "permission denied"
  # (b) is stricter: the read dies at the privilege layer before RLS is even consulted.
  if (($status -eq 401 -or $status -eq 403) -and ($errBody -match '(?i)permission denied|42501')) {
    Say ("PASS  [3/5] anon read blocked .. HTTP " + $status + " permission denied (revoke select; stricter than RLS-only)")
  } elseif ($status -eq 404) {
    Say ("FAIL  [3/5] table missing ....... HTTP 404 -- run the V3.5 SQL file in docs/ first")
    $script:fail++
  } elseif ($status -eq 401) {
    Say ("FAIL  [3/5] rejected ........... HTTP 401 -- publishable key is wrong or was rotated")
    $script:fail++
  } else {
    Say ("FAIL  [3/5] request failed ..... " + $_.Exception.Message + "  " + $errBody)
    $script:fail++
  }
}

# ---- 4) optional marked test insert ----
if ($Post) {
  if (-not $Marker) { $Marker = 'SELFCHECK-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }
  $payload = @{
    name     = $null
    relation = $null
    device   = 'selfcheck'
    message  = $Marker
    version  = $ver
  } | ConvertTo-Json -Compress
  $hdr2 = @{
    'apikey'        = $key
    'Authorization' = 'Bearer ' + $key
    'Accept'        = 'application/json'
    'Content-Type'  = 'application/json'
    'Prefer'        = 'return=minimal'
  }
  try {
    $r2 = Invoke-WebRequest -Uri $rest -Headers $hdr2 -Method Post -Body $payload -TimeoutSec $TimeoutSec -UseBasicParsing
    if ($r2.StatusCode -eq 201 -or $r2.StatusCode -eq 204) {
      Say ("PASS  [4/5] test insert ....... HTTP " + $r2.StatusCode + "  marker = " + $Marker)
    } else {
      Say ("FAIL  [4/5] test insert ....... HTTP " + $r2.StatusCode)
      $script:fail++
    }
  } catch {
    $status = 0
    $msg = $_.Exception.Message
    if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    Say ("FAIL  [4/5] test insert ....... HTTP " + $status + "  " + $msg)
    if ($status -eq 401 -or $status -eq 403) {
      Say "      Insert policy is missing or not granted to anon. Re-run section 2 of the SQL file."
    }
    $script:fail++
  }
  Say ""
  Say "NEXT -> open Supabase -> Table Editor -> feedback and look for this marker:"
  Say ("        " + $Marker)
  Say "That is the real acceptance check (courseware p.28): the row must be there."
  Say "Delete it afterwards with:"
  Say ("        delete from public.feedback where message = '" + $Marker + "';")
} else {
  Say "SKIP  [4/5] test insert ....... run again with -Post to insert a marked test row"
}

# ---- 5) cleanup reminder ----
Say ""
if ($script:fail -eq 0) {
  Say "RESULT: all checks passed (fail=0)"
  exit 0
} else {
  Say ("RESULT: fail=" + $script:fail)
  exit 1
}
