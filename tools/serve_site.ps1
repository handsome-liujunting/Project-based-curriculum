# Tiny static file server for local preview (pure PowerShell: no node/python needed).
# Uses TcpListener on loopback so no admin/URL-ACL is required, unlike HttpListener.
#   Usage:
#     Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass',
#       '-File','tools\serve_site.ps1','-Root','outputs\personal-homepage-v35','-Port','8791'
#   Stop it with:  Stop-Process -Id <pid>   (or close the window)
# The script must stay pure ASCII (Chinese text in a .ps1 gets mangled by the console).
param(
  [Parameter(Mandatory=$true)][string]$Root,
  [int]$Port = 8791
)

$ErrorActionPreference = 'Stop'
$rootFull = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')

$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.woff2' = 'font/woff2'
  '.woff' = 'font/woff'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.gif'  = 'image/gif'
  '.webp' = 'image/webp'
  '.svg'  = 'image/svg+xml'
  '.ico'  = 'image/x-icon'
  '.txt'  = 'text/plain; charset=utf-8'
  '.md'   = 'text/plain; charset=utf-8'
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "[serve_site] root : $rootFull"
Write-Host "[serve_site] open : http://127.0.0.1:$Port/"

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
    $requestLine = $reader.ReadLine()
    if (-not $requestLine) { $client.Close(); continue }
    $parts = $requestLine -split ' '
    $method = $parts[0]
    $target = if ($parts.Count -gt 1) { $parts[1] } else { '/' }
    while ($true) {
      $h = $reader.ReadLine()
      if ($h -eq $null -or $h -eq '') { break }
    }

    $pathPart = ($target -split '\?')[0]
    $rel = [System.Uri]::UnescapeDataString($pathPart).TrimStart('/')
    if ([string]::IsNullOrEmpty($rel)) { $rel = 'index.html' }
    $rel = $rel -replace '/', '\'
    $full = [System.IO.Path]::GetFullPath((Join-Path $rootFull $rel))

    $status = '404 Not Found'
    $ctype = 'text/plain; charset=utf-8'
    $body = [System.Text.Encoding]::UTF8.GetBytes('404 not found')
    if ($full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
      if (Test-Path -LiteralPath $full -PathType Leaf) {
        $body = [System.IO.File]::ReadAllBytes($full)
        $ext = [System.IO.Path]::GetExtension($full).ToLower()
        if ($mime.ContainsKey($ext)) { $ctype = $mime[$ext] }
        $status = '200 OK'
      }
    } else {
      $status = '403 Forbidden'
      $ctype = 'text/plain; charset=utf-8'
      $body = [System.Text.Encoding]::UTF8.GetBytes('403 forbidden')
    }

    $head = "HTTP/1.1 $status`r`nContent-Type: $ctype`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
    $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
    if ($method -ne 'HEAD') {
      $stream.Write($headBytes, 0, $headBytes.Length)
      $stream.Write($body, 0, $body.Length)
    } else {
      $stream.Write($headBytes, 0, $headBytes.Length)
    }
    $stream.Flush()
    Write-Host ("[serve_site] {0} {1} {2} {3} bytes" -f $method, $status.Substring(0, 3), $rel, $body.Length)
  } catch {
    Write-Host ("[serve_site] error: " + $_.Exception.Message)
  } finally {
    try { $client.Close() } catch { }
  }
}
