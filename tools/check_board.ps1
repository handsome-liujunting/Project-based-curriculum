# =============================================================================
#  V3.5 live guestbook (messages) backend check
#  Verifies the PUBLIC board table against the real Supabase project, using only
#  the publishable key -- exactly what a visitor's browser can do:
#    1) CORS preflight for POST (the browser needs this to allow the write)
#    2) anonymous READ works (visitors must see the board)
#    3) anonymous INSERT works (visitors must be able to leave a message) [-Post]
#    4) read-back: the just-inserted row is really in the database       [-Post]
#    5) UPDATE is refused
#    6) DELETE is refused
#
#  -Post IS OPT-IN ON PURPOSE: steps 3/4 write a row onto the PUBLIC board, and
#  nobody but the dashboard owner can remove it again (anon has no DELETE), so the
#  default run stays read-only. The end of the run always prints the cleanup SQL.
#
#  ASCII-only output on purpose (PowerShell 5.1 console encoding).
# =============================================================================
param(
  [string]$Root = "outputs\personal-homepage-v35",
  [string]$Marker = "",
  [string]$Origin = "https://handsome-liujunting.github.io",
  [int]$TimeoutSec = 25,
  [switch]$Post
)
$ErrorActionPreference = 'Continue'
$script:fail = 0
$script:skip = 0

function Say([string]$t) { Write-Output $t }
function StatusOf($ex) { $s = 0; if ($ex.Exception.Response) { $s = [int]$ex.Exception.Response.StatusCode }; return $s }
function ErrBody($ex) {
  try {
    if ($ex.ErrorDetails -and $ex.ErrorDetails.Message) { return [string]$ex.ErrorDetails.Message }
  } catch { }
  try {
    $rs = $ex.Exception.Response.GetResponseStream(); if (-not $rs) { return '' }
    $sr = New-Object System.IO.StreamReader($rs); $t = $sr.ReadToEnd(); $sr.Close(); return $t
  } catch { return '' }
}

$cfgPath = Join-Path $Root 'js\feedback-config.js'
if (-not (Test-Path -LiteralPath $cfgPath)) { Say "FAIL  config not found: $cfgPath"; exit 1 }
$src = [System.IO.File]::ReadAllText($cfgPath, [System.Text.Encoding]::UTF8)
$code = [regex]::Replace($src, '(?s)/\*.*?\*/', '')
$url = [regex]::Match($code, 'url\s*:\s*"([^"]*)"').Groups[1].Value.Trim().TrimEnd('/')
$key = [regex]::Match($code, 'anonKey\s*:\s*"([^"]*)"').Groups[1].Value.Trim()
$tbl = [regex]::Match($code, 'boardTable\s*:\s*"([^"]*)"').Groups[1].Value.Trim()
if (-not $tbl) { $tbl = 'messages' }
if (-not $Marker) { $Marker = 'SELFCHECK-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }

$rest = $url + '/rest/v1/' + $tbl
$hdr = @{ 'apikey' = $key; 'Authorization' = 'Bearer ' + $key; 'Accept' = 'application/json' }

Say "== V3.5 live guestbook check =="
Say ("endpoint : " + $rest)
Say ("mode     : " + $(if ($Post) { 'full (writes a marked row)' } else { 'read-only (safe; add -Post for the write test)' }))
Say ("marker   : " + $Marker)
Say ""

# ---- 1) CORS preflight (what the browser sends before a JSON POST) ----
try {
  $ph = @{
    'Origin'                         = $Origin
    'Access-Control-Request-Method'  = 'POST'
    'Access-Control-Request-Headers' = 'apikey,authorization,content-type,prefer'
  }
  $r1 = Invoke-WebRequest -Uri $rest -Headers $ph -Method Options -TimeoutSec $TimeoutSec -UseBasicParsing
  $acao = $r1.Headers['Access-Control-Allow-Origin']
  if ($acao) {
    Say ("PASS  [1/6] cors preflight ..... HTTP " + $r1.StatusCode + "  allow-origin: " + $acao)
  } else {
    Say ("FAIL  [1/6] cors preflight ..... HTTP " + $r1.StatusCode + " but no Access-Control-Allow-Origin header")
    $script:fail++
  }
} catch {
  Say ("FAIL  [1/6] cors preflight ..... HTTP " + (StatusOf $_) + "  " + (ErrBody $_))
  $script:fail++
}

# ---- 2) anonymous read ----
$before = 0
try {
  $r2 = Invoke-WebRequest -Uri ($rest + '?select=id,name,message,created_at&order=created_at.desc&limit=50') -Headers $hdr -Method Get -TimeoutSec $TimeoutSec -UseBasicParsing
  # PS 5.1 quirk: ConvertFrom-Json on "[]" yields $null, and @($null).Count is 1.
  # So decide on the raw text first, otherwise an empty table is reported as 1 row.
  $raw2 = ($r2.Content).Trim()
  $rows = @()
  if ($raw2 -and $raw2 -ne '[]') { $rows = @($raw2 | ConvertFrom-Json) }
  $before = $rows.Count
  Say ("PASS  [2/6] public read ........ HTTP " + $r2.StatusCode + "  rows = " + $before)
} catch {
  Say ("FAIL  [2/6] public read ........ HTTP " + (StatusOf $_) + "  " + (ErrBody $_))
  $script:fail++
}

if (-not $Post) {
  Say ("----  [3/6] public insert ...... not run (read-only mode; -Post runs it)")
  Say ("----  [4/6] read back .......... not run (read-only mode; -Post runs it)")
} else {

# ---- 3) anonymous insert ----
$payload = @{ name = "SELFCHECK"; message = $Marker } | ConvertTo-Json -Compress
try {
  $h3 = $hdr.Clone(); $h3['Content-Type'] = 'application/json'; $h3['Prefer'] = 'return=minimal'
  $r3 = Invoke-WebRequest -Uri $rest -Headers $h3 -Method Post -Body $payload -TimeoutSec $TimeoutSec -UseBasicParsing
  if ($r3.StatusCode -eq 201 -or $r3.StatusCode -eq 204) {
    Say ("PASS  [3/6] public insert ...... HTTP " + $r3.StatusCode + "  body = " + $payload)
  } else {
    Say ("FAIL  [3/6] public insert ...... HTTP " + $r3.StatusCode)
    $script:fail++
  }
} catch {
  $st = StatusOf $_
  Say ("FAIL  [3/6] public insert ...... HTTP " + $st + "  " + (ErrBody $_))
  if ($st -eq 401 -or $st -eq 403) { Say "      -> insert policy / grant missing for anon on $tbl" }
  $script:fail++
}

# ---- 4) read-back the row we just wrote ----
$hit = $false
try {
  $r4 = Invoke-WebRequest -Uri ($rest + '?select=id,message&message=eq.' + [uri]::EscapeDataString($Marker)) -Headers $hdr -Method Get -TimeoutSec $TimeoutSec -UseBasicParsing
  $found = @($r4.Content | ConvertFrom-Json)
  foreach ($row in $found) { if ($row.message -eq $Marker) { $hit = $true } }
  if ($hit) {
    Say ("PASS  [4/6] read back ......... marker found in the database (id = " + $found[0].id + ")")
    Say ("      NOTE: this row stays on the public board until deleted:")
    Say ("            delete from public.messages where message = '" + $Marker + "';")
  } else {
    Say ("FAIL  [4/6] read back ......... marker NOT found after a 201 insert")
    $script:fail++
  }
} catch {
  Say ("FAIL  [4/6] read back ......... HTTP " + (StatusOf $_) + "  " + (ErrBody $_))
  $script:fail++
}

}  # end of the -Post block

# ---- 5) update must be refused ----
try {
  $h5 = $hdr.Clone(); $h5['Content-Type'] = 'application/json'; $h5['Prefer'] = 'return=minimal'
  $r5 = Invoke-WebRequest -Uri ($rest + '?message=eq.' + [uri]::EscapeDataString($Marker)) -Headers $h5 -Method Patch -Body '{"name":"HACKED"}' -TimeoutSec $TimeoutSec -UseBasicParsing
  Say ("FAIL  [5/6] update refused ..... HTTP " + $r5.StatusCode + " -- an anonymous visitor could edit rows!")
  $script:fail++
} catch {
  $st = StatusOf $_
  $b = ErrBody $_
  if ($st -eq 401 -or $st -eq 403) {
    Say ("PASS  [5/6] update refused ..... HTTP " + $st + " (revoke update)")
  } elseif ($st -eq 0) {
    Say ("SKIP  [5/6] update refused ..... could not send PATCH from this shell (" + $_.Exception.Message + ")")
    $script:skip++
  } else {
    Say ("FAIL  [5/6] update refused ..... HTTP " + $st + "  " + $b)
    $script:fail++
  }
}

# ---- 6) delete must be refused ----
try {
  $h6 = $hdr.Clone(); $h6['Prefer'] = 'return=minimal'
  $r6 = Invoke-WebRequest -Uri ($rest + '?message=eq.' + [uri]::EscapeDataString($Marker)) -Headers $h6 -Method Delete -TimeoutSec $TimeoutSec -UseBasicParsing
  Say ("FAIL  [6/6] delete refused ..... HTTP " + $r6.StatusCode + " -- an anonymous visitor could delete rows!")
  $script:fail++
} catch {
  $st = StatusOf $_
  $b = ErrBody $_
  if ($st -eq 401 -or $st -eq 403) {
    Say ("PASS  [6/6] delete refused ..... HTTP " + $st + " (revoke delete)")
  } elseif ($st -eq 0) {
    Say ("SKIP  [6/6] delete refused ..... could not send DELETE from this shell (" + $_.Exception.Message + ")")
    $script:skip++
  } else {
    Say ("FAIL  [6/6] delete refused ..... HTTP " + $st + "  " + $b)
    $script:fail++
  }
}

Say ""
Say ("RESULT: fail=" + $script:fail + " skip=" + $script:skip + "  (rows before = " + $before + ")")
if ($script:fail -eq 0) { exit 0 } else { exit 1 }
