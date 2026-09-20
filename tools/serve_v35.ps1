# Minimal static file server for local preview (pure ASCII script).
# TcpListener avoids the HttpListener URL ACL requirement on Windows.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Port 8123 -Root outputs\personal-homepage-v35
param(
  [int]$Port = 8123,
  [string]$Root = 'outputs\personal-homepage-v35'
)

$ErrorActionPreference = 'Stop'
$rootFull = (Resolve-Path -LiteralPath $Root).Path
if (-not (Test-Path -LiteralPath (Join-Path $rootFull 'index.html'))) {
  Write-Output "ERROR: no index.html under $rootFull"
  exit 1
}
Write-Output "serving $rootFull on http://127.0.0.1:$Port/"

$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.mjs'  = 'application/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.woff2' = 'font/woff2'
  '.woff' = 'font/woff'
  '.ttf'  = 'font/ttf'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.gif'  = 'image/gif'
  '.svg'  = 'image/svg+xml'
  '.ico'  = 'image/x-icon'
  '.md'   = 'text/plain; charset=utf-8'
  '.txt'  = 'text/plain; charset=utf-8'
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $client.NoDelay = $true
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
    $requestLine = $reader.ReadLine()
    if ([string]::IsNullOrWhiteSpace($requestLine)) { $client.Close(); continue }
    while ($true) {
      $h = $reader.ReadLine()
      if ($null -eq $h -or $h -eq '') { break }
    }
    $parts = $requestLine.Split(' ')
    $method = $parts[0]
    $target = $parts[1]
    $pathOnly = $target.Split('?')[0]
    if ($pathOnly -eq '/' -or $pathOnly -eq '') { $pathOnly = '/index.html' }
    $pathOnly = [System.Uri]::UnescapeDataString($pathOnly)
    $rel = ($pathOnly.TrimStart('/')) -replace '/', '\'
    $full = Join-Path $rootFull $rel

    $status = '200 OK'
    $body = $null
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
      $status = '404 Not Found'
      $body = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
      $ctype = 'text/plain; charset=utf-8'
    }
    elseif (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
      $status = '403 Forbidden'
      $body = [System.Text.Encoding]::UTF8.GetBytes('403 Forbidden')
      $ctype = 'text/plain; charset=utf-8'
    }
    else {
      $ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
      if ($mime.ContainsKey($ext)) { $ctype = $mime[$ext] } else { $ctype = 'application/octet-stream' }
      $body = [System.IO.File]::ReadAllBytes($full)
    }

    $head = "HTTP/1.1 $status`r`n" +
            "Content-Type: $ctype`r`n" +
            "Content-Length: $($body.Length)`r`n" +
            "Cache-Control: no-store`r`n" +
            "Connection: close`r`n`r`n"
    $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
    $stream.Write($headBytes, 0, $headBytes.Length)
    if ($method -ne 'HEAD') { $stream.Write($body, 0, $body.Length) }
    $stream.Flush()
  }
  catch {
    # keep serving on any per-connection error
  }
  finally {
    try { $client.Close() } catch { }
  }
}
