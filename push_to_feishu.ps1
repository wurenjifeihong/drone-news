# push_to_feishu.ps1 - 飞书消息推送
param([string]$Title, [int]$NewsCount, [int]$BidCount)

$config = Get-Content (Join-Path $PSScriptRoot "push_config.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$webhook = $config.feishu_webhook

if (-not $webhook) {
    Write-Output "push_config.json 未配置飞书 Webhook，跳过推送"
    exit 0
}

$msg = @{
    msg_type = "interactive"
    card = @{
        header = @{
            title = @{ tag = "plain_text"; content = "🚁 低空经济通 · 每日更新" }
            template = "blue"
        }
        elements = @(
            @{
                tag = "div"
                text = @{
                    tag = "lark_md"
                    content = "**📰 无人机新闻**: ${NewsCount}条`n**📋 无人机招投标**: ${BidCount}条`n`n🔥 ${Title}"
                }
            },
            @{
                tag = "action"
                actions = @(
                    @{
                        tag = "button"
                        text = @{ tag = "plain_text"; content = "打开页面" }
                        url = "https://wurenjifeihong.github.io/drone-news/"
                        type = "primary"
                    }
                )
            }
        )
    }
} | ConvertTo-Json -Depth 5 -Compress

try {
    $result = Invoke-RestMethod -Uri $webhook -Method POST -Body $msg -ContentType "application/json" -TimeoutSec 10
    Write-Output "飞书推送成功! StatusCode: $($result.StatusCode)"
} catch {
    Write-Output "飞书推送失败: $_"
}
