# V3.5 structure / asset / link verification (pure ASCII script)
param([Parameter(Mandatory=$true)][string]$Root)

$ErrorActionPreference = 'Stop'
$fail = 0

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
foreach ($rel in @('css\style.css','css\feedback.css','js\main.js','js\feedback.js','js\feedback-config.js')) {
  $name = Split-Path $rel -Leaf
  if (Test-Path -LiteralPath (Join-Path $Root $rel)) {
    $used = $html -match [regex]::Escape($name)
    Say ("  {0}  referenced={1}" -f $rel, $used)
    if (-not $used) { $fail++ }
  } else { Say "  MISS $rel"; $fail++ }
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
Say "===== 5) 脚本顺序（config 必须先于 feedback.js） ====="
$iCfg = $html.IndexOf('js/feedback-config.js')
$iFb  = $html.IndexOf('js/feedback.js"')
$iMain= $html.IndexOf('js/main.js')
Say "  main=$iMain  config=$iCfg  feedback=$iFb"
if (-not ($iCfg -gt 0 -and $iFb -gt $iCfg)) { Say "  FAIL order"; $fail++ } else { Say "  ok  config loaded before feedback" }

Say ""
Say "===== 6) 外部链接扫描（HTML/CSS/JS） ====="
$ext = @()
foreach ($f in (Get-ChildItem -LiteralPath $Root -Recurse -File |
                Where-Object { $_.Extension -in '.html','.css','.js' })) {
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
foreach ($f in (Get-ChildItem -LiteralPath $Root -Recurse -File |
                Where-Object { $_.Extension -in '.html','.css','.js','.md','.txt' })) {
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
Say "===== 汇总 ====="
Say "  FAIL count = $fail"
