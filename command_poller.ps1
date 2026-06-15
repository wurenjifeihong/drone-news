# command_poller.ps1 - 每分钟检查飞书发来的命令并执行
$repo = "C:\Users\LEGION\Documents\无人机"
$token = Get-Content (Join-Path $repo ".github_token") -Raw -Encoding ASCII
$headers = @{ Authorization = "Bearer $token"; Accept = "application/vnd.github+json" }
$issueLabel = "feishu-command"

while ($true) {
    try {
        # Check for pending commands
        $issues = Invoke-RestMethod -Uri "https://api.github.com/repos/wurenjifeihong/drone-news/issues?labels=$issueLabel&state=open" `
            -Headers $headers -TimeoutSec 10
        
        foreach ($issue in $issues) {
            $body = $issue.body
            $cmdTag = [regex]::Match($body, '<!--cmd:(.+?)-->')
            if (-not $cmdTag.Success) { continue }
            
            $cmd = $cmdTag.Groups[1].Value.Trim()
            Write-Output "Executing: $cmd"
            
            $result = ""
            try {
                switch -Wildcard ($cmd) {
                    "update-news" {
                        $result = & powershell -ExecutionPolicy Bypass -File (Join-Path $repo "fetch_drone_news.ps1") 2>&1 | Out-String
                    }
                    "status" {
                        $info = Invoke-RestMethod -Uri "https://api.github.com/repos/wurenjifeihong/drone-news/commits?per_page=1" -Headers $headers
                        $d = [DateTime]$info[0].commit.author.date
                        $result = "最新更新: $($d.ToLocalTime().ToString('yyyy-MM-dd HH:mm'))`nhttps://wurenjifeihong.github.io/drone-news/"
                    }
                    default {
                        $result = "未知命令: $cmd"
                    }
                }
            } catch {
                $result = "执行失败: $_"
            }
            
            # Comment result and close issue
            $comment = @{ body = "✅ 执行完成:`n`n``````n$result`n``````n" } | ConvertTo-Json
            Invoke-RestMethod -Uri $issue.comments_url -Method POST -Body $comment -ContentType "application/json" -Headers $headers
            Invoke-RestMethod -Uri $issue.url -Method PATCH -Body '{"state":"closed"}' -ContentType "application/json" -Headers $headers
            
            Write-Output "Command completed: $cmd"
        }
    } catch {
        # Silently retry
    }
    
    Start-Sleep -Seconds 30
}
