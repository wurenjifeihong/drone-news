# push_to_qq.ps1 - QQ消息推送
param([string]$Title, [string]$Content, [int]$NewsCount, [int]$BidCount)

$config = Get-Content (Join-Path $PSScriptRoot "push_config.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$key = $config.qq_push_key
$qq = $config.qq_number

if (-not $key) {
    Write-Output "push_config.json 未配置 QQ Push Key，跳过推送"
    Write-Output "获取 Key: https://qmsg.zendee.cn → QQ登录 → 控制台 → 复制 Key"
    exit 0
}

$msg = "🚁 低空经济通 · 每日更新`n`n📰 无人机新闻: ${NewsCount}条`n📋 无人机招投标: ${BidCount}条`n`n🔗 https://wurenjifeihong.github.io/drone-news/`n`n━━━━━━━━━━`n${Title}"

# Truncate if too long (QQ message limit)
if ($msg.Length -gt 800) { $msg = $msg.Substring(0, 797) + "..." }

$body = @{ msg = $msg }
if ($qq) { $body.qq = $qq }

try {
    $result = Invoke-RestMethod -Uri "https://qmsg.zendee.cn/send/$key" `
        -Method POST -Body $body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 10
    if ($result.success) {
        Write-Output "QQ推送成功!"
    } else {
        Write-Output "QQ推送失败: $($result.reason)"
    }
} catch {
    Write-Output "QQ推送异常: $_"
}
