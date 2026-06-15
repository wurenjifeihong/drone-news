# serve.ps1 - Simple HTTP server for docs/
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()
Write-Output "Server running on http://localhost:8080"

$docsPath = Join-Path $PSScriptRoot "docs"
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $resp = $ctx.Response
    $path = $req.Url.LocalPath
    if ($path -eq "/" -or $path -eq "/index.html") {
        $file = Join-Path $docsPath "index.html"
    } else {
        $file = Join-Path $docsPath ($path.TrimStart('/'))
    }
    if (Test-Path $file) {
        $content = [System.IO.File]::ReadAllBytes($file)
        if ($file.EndsWith(".html")) { $resp.ContentType = "text/html; charset=utf-8" }
        elseif ($file.EndsWith(".css")) { $resp.ContentType = "text/css" }
        elseif ($file.EndsWith(".js")) { $resp.ContentType = "application/javascript" }
        else { $resp.ContentType = "application/octet-stream" }
        $resp.OutputStream.Write($content, 0, $content.Length)
    } else {
        $resp.StatusCode = 404
        $msg = [System.Text.Encoding]::UTF8.GetBytes("Not Found")
        $resp.OutputStream.Write($msg, 0, $msg.Length)
    }
    $resp.Close()
}
