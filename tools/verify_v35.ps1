# V3.5 structure / asset / link verification (pure ASCII script)
#   -Root <folder>   the site source folder (or the repo root when it IS the publish root)
#   -SiteOnly        only scan the published site files (index.html + css\ + js\ + assets\),
#                    instead of walking the whole folder tree. Use this when -Root is the
#                    repo root, so uploads\ / outputs\ / docs\ are not scanned.
param(
  [Parameter(Mandatory=$true)][string]$Root,
  [switch]$SiteOnly
)

$ErrorActionPreference = 'Stop'
$fail = 0

# --- decide which files are in scope -----------------------------------------
if ($SiteOnly) {
  $scan = @()
  foreach ($d in @('css','js','assets')) {
    $p = Join-Path $Root $d
    if (Test-Path -LiteralPath $p) { $scan += @(Get-ChildItem -LiteralPath $p -Recurse -File) }
  }
  $idx = Join-Path $Root 'index.html'
  if (Test-Path -LiteralPath $idx) { $scan += @(Get-Item -LiteralPath $idx) }
  Write-Output "scope: site files only ($($scan.Count) files)"
} else {
  $scan = @(Get-ChildItem -LiteralPath $Root -Recurse -File)
  Write-Output "scope: all files under Root ($($scan.Count) files)"
}
Write-Output ""

function Strip-Comments($t) {
  $t = [regex]::Replace($t, '/\*.*?\*/', ' ', 'Singleline')
  $t = [regex]::Replace($t, '(?m)^\s*//.*$', ' ')
  return $t
}

function Say($s) { Write-Output $s }

$index = Join-Path $Root 'index.html'
$html = [System.IO.File]::ReadAllText($index, [System.Text.Encoding]::UTF8)

Say "===== 1) 引用的本地文件是否存在 ====="
$refs = [regex]::Matches($html, '(?:src|href)="([^"#:]+?)"') | ForEach-Object { $_.Groups[1].Value }
foreach ($r in ($refs | Sort-Object -Unique)) {
  $p = Join-Path $Root ($r -replace '/', '\')
  if (Test-Path -LiteralPath $p) { Say "  ok   $r" }
  else { Say "  MISS $r"; $fail++ }
}

Say ""
Say "===== 2) 样式/脚本文件是否都被引用 ====="
# 自动发现 css\ 与 js\ 下的所有文件（不再写死清单），
# 这样以后新增文件如果忘了在 HTML 里引用，这里会直接 FAIL。
$assets = @()
foreach ($sub in @('css','js')) {
  $d = Join-Path $Root $sub
  if (Test-Path -LiteralPath $d) {
    $assets += @(Get-ChildItem -LiteralPath $d -Recurse -File |
                 Where-Object { $_.Extension -in '.css','.js' })
  }
}
if ($assets.Count -eq 0) { Say "  MISS no css/js file found under Root"; $fail++ }
foreach ($f in ($assets | Sort-Object FullName)) {
  $used = $html -match [regex]::Escape($f.Name)
  Say ("  {0}  referenced={1}" -f $f.FullName.Substring((Resolve-Path $Root).Path.Length).TrimStart('\'), $used)
  if (-not $used) { $fail++ }
}

Say ""
Say "===== 3) id 唯一性 ====="
$ids = [regex]::Matches($html, '\sid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
$dup = $ids | Group-Object | Where-Object { $_.Count -gt 1 }
if ($dup) { $dup | ForEach-Object { Say "  DUP id: $($_.Name) x$($_.Count)"; $fail++ } }
else { Say "  ok  $($ids.Count) ids, no duplicates" }

Say ""
Say "===== 4) 标签配对（主要容器） ====="
foreach ($tag in @('div','section','form','fieldset','button','label','p','article','span','nav','header','footer','main','h2','h3','textarea','aside','svg')) {
  $open  = ([regex]::Matches($html, "<$tag(\s|>)")).Count
  $close = ([regex]::Matches($html, "</$tag>")).Count
  $selfc = ([regex]::Matches($html, "<$tag\s[^>]*/>")).Count
  $status = if (($open - $selfc) -eq $close) { 'ok  ' } else { 'FAIL' }
  if ($status -eq 'FAIL') { $fail++ }
  Say ("  {0} <{1}> open={2} self={3} close={4}" -f $status, $tag, $open, $selfc, $close)
}

Say ""
Say "===== 5) 脚本顺序（config 必须先于 feedback.js / board.js） ====="
$iCfg = $html.IndexOf('js/feedback-config.js')
$iFb  = $html.IndexOf('js/feedback.js"')
$iBd  = $html.IndexOf('js/board.js"')
$iMain= $html.IndexOf('js/main.js')
Say "  main=$iMain  config=$iCfg  feedback=$iFb  board=$iBd"
if (-not ($iCfg -gt 0 -and $iFb -gt $iCfg)) { Say "  FAIL order (config before feedback)"; $fail++ }
else { Say "  ok  config loaded before feedback" }
if (-not ($iCfg -gt 0 -and $iBd -gt $iCfg)) { Say "  FAIL order (config before board)"; $fail++ }
else { Say "  ok  config loaded before board" }

Say ""
Say "===== 6) 外部链接扫描（HTML/CSS/JS） ====="
$ext = @()
foreach ($f in ($scan | Where-Object { $_.Extension -in '.html','.css','.js' })) {
  $t = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
  if ($f.Extension -ne '.html') { $t = Strip-Comments $t }
  foreach ($m in [regex]::Matches($t, 'https?://[^\s"''<>)]+')) {
    $ext += ("{0} :: {1}" -f $f.Name, $m.Value)
  }
}
Say "  (comments stripped; inline html comments not stripped)"
if ($ext.Count -eq 0) { Say "  ok  no external url in html/css/js (except comments)" }
else { $ext | Sort-Object -Unique | ForEach-Object { Say "  ext $_" } }

Say ""
Say "===== 7) 文件编码 / BOM ====="
foreach ($f in ($scan | Where-Object { $_.Extension -in '.html','.css','.js','.md','.txt' })) {
  $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
  $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  Say ("  {0,-32} {1,8} bytes  bom={2}" -f $f.Name, $bytes.Length, $bom)
}

Say ""
Say "===== 8) safety: key material in front-end files ====="
$cfg = [System.IO.File]::ReadAllText((Join-Path $Root 'js\feedback-config.js'), [System.Text.Encoding]::UTF8)
$cfgCode = Strip-Comments $cfg
$bad = @()
if ($cfgCode -match 'eyJ[A-Za-z0-9_\-]{20,}\.') { $bad += 'found something that looks like a JWT' }
if ($cfgCode -match 'service_role') { $bad += 'service_role referenced in CODE (not comment)' }
if ($cfgCode -match 'SUPABASE_SERVICE') { $bad += 'service env name in CODE' }
if ($bad) { $bad | ForEach-Object { Say "  WARN $_"; $script:fail++ } } else { Say "  ok  no key material / service_role in config code" }

Say ""
Say "===== 9) JS <-> HTML contract (ids and data- attributes) ====="
# Why this exists: js/digital-twin.js asked for getElementById("dtPicks") while the
# HTML only had class="dt-picks". The value came back null, the guard at the top of
# the script returned silently, and the whole twin feature (button, Q&A, deep link)
# was dead -- with no error anywhere and with the id-count check still green.
# So: match every id / data- attribute a script asks for against index.html.
$htmlIdList = [regex]::Matches($html, '\sid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
$jsDir = Join-Path $Root 'js'
$jsFiles = @()
if (Test-Path -LiteralPath $jsDir) { $jsFiles = @(Get-ChildItem -LiteralPath $jsDir -Filter *.js -File) }
$contractChecked = 0
foreach ($jsFile in $jsFiles) {
  $jsCode = Strip-Comments ([System.IO.File]::ReadAllText($jsFile.FullName, [System.Text.Encoding]::UTF8))
  foreach ($m in [regex]::Matches($jsCode, 'getElementById\(\s*[''"]([^''"]+)[''"]\s*\)')) {
    $contractChecked++
    $id = $m.Groups[1].Value
    if ($htmlIdList -contains $id) { Say "  ok   $($jsFile.Name)  #$id" }
    else { Say "  MISS $($jsFile.Name)  #$id  (no such id in index.html)"; $fail++ }
  }
  foreach ($m in [regex]::Matches($jsCode, 'querySelectorAll?\(\s*[''"]\[([a-zA-Z][a-zA-Z0-9-]*)\]')) {
    $contractChecked++
    $attr = $m.Groups[1].Value
    if ($html -match ("\s" + [regex]::Escape($attr) + "(\s|=|>)")) { Say "  ok   $($jsFile.Name)  [$attr]" }
    else { Say "  MISS $($jsFile.Name)  [$attr]  (attribute never used in index.html)"; $fail++ }
  }
}
if ($contractChecked -eq 0) { Say "  WARN no getElementById/attribute selector found to check" }

Say ""
Say "===== 10) XSS guard + guestbook contract ====="
# Why this exists: the guestbook renders text that strangers typed. If any script
# builds that HTML by string concatenation, one visitor posting "<script>...</script>"
# would run code inside every other visitor's browser. So: forbid the HTML-string
# sinks in js\ completely, and require the board section to carry its public warning.
$sinks = @('innerHTML', 'insertAdjacentHTML', 'outerHTML', 'document.write')
$sinkHit = 0
foreach ($jsFile in $jsFiles) {
  $jsCode = Strip-Comments ([System.IO.File]::ReadAllText($jsFile.FullName, [System.Text.Encoding]::UTF8))
  foreach ($s in $sinks) {
    if ($jsCode -match [regex]::Escape($s)) {
      Say "  FAIL $($jsFile.Name) uses $s  (visitor text must be inserted as text, not HTML)"
      $sinkHit++; $fail++
    }
  }
}
if ($sinkHit -eq 0) { Say "  ok   no HTML-string sink in js\ (textContent only)" }

# the guestbook block itself: it must exist, and it must say out loud that it is public
if ($htmlIdList -contains 'board') { Say "  ok   #board section present" }
else { Say "  MISS #board section in index.html"; $fail++ }
if ($html -match 'board__notice') { Say "  ok   public warning block present (visitors know it is public)" }
else { Say "  MISS public warning block (board__notice) in the guestbook section"; $fail++ }

Say ""
Say "===== 汇总 ====="
Say "  FAIL count = $fail"
