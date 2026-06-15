# setup_news_task.ps1 — 注册每日无人机新闻抓取计划任务
# 需要以管理员身份运行

$taskName = "Codex-每日无人机新闻"
$scriptPath = "C:\Users\LEGION\Documents\无人机\fetch_drone_news.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Daily -At "08:00"
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

try {
    Register-ScheduledTask -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "每天早上 8:00 抓取中文无人机新闻到 每日无人机资讯.md" `
        -Force
    Write-Output "OK: 计划任务已注册 — 每天 08:00 运行"
} catch {
    Write-Output "ERROR: $_"
    Write-Output "请以管理员身份运行此脚本。"
}
