# =====================================================================
# Measure the real tall-render offsets used by shots_v35.ps1.
# Renders index.html at 1440xTallH with ?full=1 (hero pinned) and dumps the
# DOM, where an injected probe has written every section's offsetTop/height
# plus the document height. Pure ASCII script.
#   powershell -File tools\probe_v35.ps1 -Root outputs\personal-homepage-v35
# =====================================================================
param(
  [Parameter(Mandatory=$true)][string]$Root,
  [string]$Edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
  [int]$Width = 1440,
  [int]$TallH = 5400,
  # Query string to measure. Default is the tall-render mode used by 01..07.
  # Use '?only=board' to measure the isolated guestbook shot (13/14).
  [string]$Query = '?full=1'
)
$ErrorActionPreference = 'Continue'

$rootAbs = (Resolve-Path -LiteralPath $Root).Path
$tmpBase = Join-Path $env:TEMP 'opencode'
$work    = Join-Path $tmpBase 'v35probe'
$prof    = Join-Path $tmpBase 'edgeprofile-probe'
$dump    = Join-Path $tmpBase 'probe-dom.html'

foreach ($p in @($work, $prof)) {
  if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
  New-Item -ItemType Directory -Path $p -Force | Out-Null
}
Copy-Item -Path (Join-Path $rootAbs '*') -Destination $work -Recurse -Force

$helper = '<script>(function(){' +
  'var css=".reveal{opacity:1 !important;transform:none !important;transition:none !important}";' +
  'var q=location.search||"";' +
  'if(/[?&]full=1/.test(q)){css+=".hero{min-height:725px !important}"}' +
  'if(/[?&]only=board/.test(q)){css+="header.topbar,main#main>section:not(#board),footer.site-footer{display:none !important}"+' +
    '"main#main{padding-top:0 !important}#board{padding-top:48px !important;padding-bottom:48px !important}"}' +
  'var s=document.createElement("style");s.textContent=css;document.head.appendChild(s);' +
  'window.addEventListener("load",function(){setTimeout(function(){' +
    'var out=[];var secs=document.querySelectorAll("main section, footer");' +
    'for(var i=0;i<secs.length;i++){var el=secs[i];var r=el.getBoundingClientRect();' +
      'out.push({tag:el.tagName.toLowerCase(),id:el.id||"",kids:el.children.length,top:Math.round(r.top+window.scrollY),h:Math.round(r.height)});}' +
    'var pre=document.createElement("pre");pre.id="probe";' +
    'pre.textContent=JSON.stringify({vw:window.innerWidth,vh:window.innerHeight,docH:document.documentElement.scrollHeight,secs:out});' +
    'document.body.appendChild(pre);' +
  '},1200);});' +
'})();</script>'

$idx  = Join-Path $work 'index.html'
$html = [System.IO.File]::ReadAllText($idx, [System.Text.Encoding]::UTF8)
$html = $html.Replace('</body>', $helper + '</body>')
[System.IO.File]::WriteAllText($idx, $html, (New-Object System.Text.UTF8Encoding($false)))

$url = 'file:///' + ($work -replace '\\', '/') + '/index.html' + $Query
if (Test-Path -LiteralPath $dump) { Remove-Item -LiteralPath $dump -Force }

# Warm the profile once (first launch paints Edge's own surface) and discard it.
$warm = Join-Path $tmpBase 'probe-warm.png'
& $Edge @('--headless=new','--disable-gpu','--hide-scrollbars','--no-first-run',
  '--no-default-browser-check','--disable-extensions',"--user-data-dir=$prof",
  '--force-device-scale-factor=1','--virtual-time-budget=3000','--window-size=1200,800',
  "--screenshot=$warm", $url) 2>$null | Out-Null
Start-Sleep -Milliseconds 500
if (Test-Path -LiteralPath $warm) { Remove-Item -LiteralPath $warm -Force }

$args1 = '--headless=new --disable-gpu --hide-scrollbars --no-first-run --no-default-browser-check ' +
         '--disable-extensions --force-device-scale-factor=1 --virtual-time-budget=9000 ' +
         '--user-data-dir="' + $prof + '" --window-size=' + $Width + ',' + $TallH + ' --dump-dom "' + $url + '"'
$null = Start-Process -FilePath $Edge -ArgumentList $args1 -RedirectStandardOutput $dump -NoNewWindow -Wait -PassThru
$size = (Get-Item -LiteralPath $dump).Length
Write-Output ("dump bytes = " + $size)
if ($size -lt 500) { Write-Output 'FATAL: empty dump'; exit 1 }

$dom = [System.IO.File]::ReadAllText($dump, [System.Text.Encoding]::UTF8)
$m = [regex]::Match($dom, '<pre id="probe">(.*?)</pre>', 'Singleline')
if (-not $m.Success) { Write-Output 'FATAL: probe block not found'; exit 1 }
$json = $m.Groups[1].Value.Replace('&lt;','<').Replace('&gt;','>').Replace('&amp;','&').Replace('&quot;','"')

$data = $json | ConvertFrom-Json
Write-Output ("viewport = " + $data.vw + "x" + $data.vh + "   docH = " + $data.docH)
Write-Output ''
Write-Output 'index  top     height  tag     id'
$i = 0
foreach ($s in $data.secs) {
  $i++
  Write-Output (('{0,5}  {1,6}  {2,6}  {3,-7} {4}' -f $i, $s.top, $s.h, $s.tag, $s.id))
}
Write-Output ''
Write-Output ("docH - 900 = " + ($data.docH - 900))
