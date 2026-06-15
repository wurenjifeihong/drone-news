# fetch_drone_news.ps1 — 无人机日报 (双栏排版 + 北京时间 + 福建招标)
$ErrorActionPreference = "Continue"
$desktop = "$env:USERPROFILE\Desktop"
$outputHtml = Join-Path $desktop "每日无人机资讯.html"
$docsOutput = Join-Path $PSScriptRoot "docs\index.html"

$dateStr = Get-Date -Format "yyyy-MM-dd"
$wdCN = @{Sunday="日";Monday="一";Tuesday="二";Wednesday="三";Thursday="四";Friday="五";Saturday="六"}[(Get-Date).DayOfWeek.ToString()]
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

function Get-CloseTag($h, $ot, $sp) {
    $tn = if ($ot -match '<(\w+)') { $Matches[1] } else { return -1 }
    $d = 1; $p = $sp
    while ($d -gt 0) {
        $no = $h.IndexOf("<$tn", $p); $nc = $h.IndexOf("</$tn>", $p)
        if ($nc -lt 0) { return $p }
        if ($no -ge 0 -and $no -lt $nc) { $d++; $p = $no + $tn.Length + 1 }
        else { $d--; $p = $nc + $tn.Length + 3 }
    }
    return $p
}

function Fetch-News($keywords) {
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($kw in $keywords) {
        $enc = [System.Net.WebUtility]::UrlEncode($kw)
        try {
            $web = Invoke-WebRequest -Uri "https://news.so.com/ns?q=${enc}&src=news_search&rank=pdate" -TimeoutSec 10 -UseBasicParsing -Headers @{"User-Agent"=$ua}
            $html = $web.Content
            $cards = [regex]::Matches($html, '<li[^>]*class="[^"]*full-txt[^"]*res-list[^"]*"[^>]*>')
            foreach ($card in $cards) {
                $cs = $card.Index; $ce = Get-CloseTag $html $card.Value ($cs + $card.Length)
                if ($ce -le $cs) { continue }
                $block = $html.Substring($cs, $ce - $cs)
                $tm = [regex]::Match($block, '<div[^>]*class="[^"]*g-txt-inner[^"]*"[^>]*>(.+?)</div>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
                if (-not $tm.Success) { continue }
                $title = [System.Net.WebUtility]::HtmlDecode($tm.Groups[1].Value) -replace '<[^>]+>', '' -replace '\s+', ' ' -replace '^\s+|\s+$', ''
                if ($title.Length -lt 8 -or $title -notmatch '[\p{IsCJKUnifiedIdeographs}]') { continue }
                $lm = [regex]::Match($block, '<a[^>]*href="([^"]+)"[^>]*title='); if (-not $lm.Success) { $lm = [regex]::Match($block, 'data-url="([^"]+)"') }
                $url = if ($lm.Success) { $lm.Groups[1].Value } else { "" }
                $sm = [regex]::Match($block, '<p[^>]*class="[^"]*summary[^"]*"[^>]*>(.+?)</p>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
                $summary = ""; if ($sm.Success) { $summary = [System.Net.WebUtility]::HtmlDecode($sm.Groups[1].Value) -replace '<[^>]+>', '' -replace '\s+', ' ' -replace '^\s+|\s+$', '' }
                $srcm = [regex]::Match($block, '<cite[^>]*class="[^"]*sitename[^"]*"[^>]*>([^<]+)</cite>')
                $source = if ($srcm.Success) { $srcm.Groups[1].Value.Trim() } else { "360新闻" }
                $tim = [regex]::Match($block, '<span[^>]*class="[^"]*time[^"]*"[^>]*>([^<]+)</span>')
                $timeStr = if ($tim.Success) { $tim.Groups[1].Value.Trim() } else { "" }
                if ($items | Where-Object { $_.Title -eq $title }) { continue }
                $items.Add([PSCustomObject]@{Title=$title; Link=$url; Summary=$summary; Source=$source; Time=$timeStr})
            }
        } catch { Write-Output "WARN: $kw $_" }
    }
    return ($items | Sort-Object { $t = $_.Time; if ($t -match '秒|分钟|刚刚'){"A$t"}elseif($t -match '小时'){"B$t"}elseif($t -match '昨天'){"C$t"}else{"Z$t"} })
}

# ====== Fetch ======
Write-Output "抓取无人机新闻..."
$allItems = Fetch-News @("无人机", "低空经济", "大疆", "航拍", "无人机巡检", "SLAM激光扫描", "高斯泼溅", "点云模型")
Write-Output "抓取福建招标..."
$bidItems = Fetch-News @("福建 无人机 招标", "福建省 无人机 采购", "福建 无人机 中标", "福建 低空经济 招标", "福建 无人机 项目", "福建 SLAM 激光扫描", "福建 高斯泼溅", "福建 点云模型")
$bidItems = $bidItems | Where-Object { $_.Title -match "无人机|UAV|drone|航拍|多旋翼|固定翼|无人飞行|SLAM|激光扫描|高斯泼溅|点云" } | Where-Object { $_.Title -match "福建|福州|厦门|泉州|漳州|龙岩|三明|南平|莆田|宁德" }

# ====== Build cards ======
function Build-Cards($items, $cls, $numCls, $bdgCls) {
    $html = ""; $i = 0
    foreach ($item in $items) { $i++
        $t = [System.Security.SecurityElement]::Escape($item.Title)
        $s = [System.Security.SecurityElement]::Escape($item.Summary)
        $src = [System.Security.SecurityElement]::Escape($item.Source)
        $tm = [System.Security.SecurityElement]::Escape($item.Time)
        $lk = [System.Security.SecurityElement]::Escape($item.Link)
        $tl = if ($item.Link) { "<h3 class=`"card-title`"><a href=`"$lk`" target=`"_blank`" class=`"title-link`">$t</a></h3>" } else { "<h3 class=`"card-title`">$t</h3>" }
        $html += "      <div class=`"card $cls`"><div class=`"card-num $numCls`">$i</div><div class=`"card-body`">$tl<div class=`"card-meta`"><span class=`"badge $bdgCls`">$src</span><span>$tm</span></div><p class=`"card-summary`">$s</p></div></div>`n"
    }
    if ($items.Count -eq 0) { $html = '<div style="padding:30px;text-align:center;color:var(--text2);font-size:14px">暂无相关信息</div>' }
    return $html
}
$newsCards = Build-Cards $allItems "" "" ""
$bidCards = Build-Cards $bidItems "bid-card" "bid-num" "bid-badge"

# ====== Read existing HTML ======
$existingHtml = ""
$existingDates = @()
if (Test-Path $outputHtml) {
    $eh = Get-Content $outputHtml -Raw -Encoding UTF8
    $dm = [regex]::Matches($eh, '<!-- SECTION:([^>]+) -->')
    foreach ($m in $dm) { $existingDates += $m.Groups[1].Value }
    $bm = [regex]::Match($eh, '<div class="news-col"[^>]*>(.*?)</div>\s*<div class="bid-col"', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($bm.Success) { $existingHtml = $bm.Groups[1].Value }
}
if ($existingDates -contains $dateStr) {
    $existingHtml = [regex]::Replace($existingHtml, "<!-- SECTION:$dateStr -->[\s\S]*?(?=<!-- SECTION:|$)", "")
}

# ====== Today section ======
$todaySection = @"
<!-- SECTION:$dateStr -->
<div class="date-section" data-date="$dateStr">
  <div class="date-header" onclick="this.parentElement.classList.toggle('collapsed')">
    <h2>无人机新闻</h2><span class="date-count">$($allItems.Count)条</span><span class="arrow">▼</span>
  </div>
  <div class="date-body">$newsCards</div>
</div>
"@

# ====== Date tabs ======
$allDates = @($dateStr) + ($existingDates | Where-Object { $_ -ne $dateStr } | Sort-Object -Descending)
$tabHtml = ($allDates | ForEach-Object { "<button class=`"date-tab`" onclick=`"scrollToDate('$_')`">$_</button>" }) -join ""

# ====== Style ======
$style = @"
<style>
:root{--bg:#f0f2f5;--card:#fff;--text:#1a1a2e;--text2:#6b7280;--accent:#2563eb;--green:#059669;--radius:12px}
*{margin:0;padding:0;box-sizing:border-box}
body{background:var(--bg);font-family:"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;color:var(--text);line-height:1.6;-webkit-font-smoothing:antialiased}
.header{background:linear-gradient(160deg,#0f172a,#1e3a5f,#1a3a5c);color:#fff;padding:28px 24px 22px;text-align:center;position:relative;overflow:hidden}
.header::before{content:'';position:absolute;top:-40%;right:-15%;width:240px;height:240px;background:radial-gradient(circle,rgba(255,255,255,.05),transparent 70%);border-radius:50%}
.header h1{font-size:28px;font-weight:800;letter-spacing:1px;margin-bottom:6px;position:relative;z-index:1}
.header .sub{font-size:12px;opacity:.75;position:relative;z-index:1}
.tab-bar{display:flex;flex-wrap:wrap;gap:5px;justify-content:center;padding:10px 14px;background:var(--card);border-bottom:1px solid #e5e7eb;position:sticky;top:0;z-index:100;backdrop-filter:blur(8px)}
.date-tab{background:#eff6ff;color:var(--accent);border:1px solid #bfdbfe;padding:5px 14px;border-radius:16px;font-size:12px;cursor:pointer;transition:all .15s;font-weight:500}
.date-tab:hover{background:var(--accent);color:#fff;border-color:var(--accent);transform:translateY(-1px)}
.main-layout{max-width:1200px;margin:0 auto;padding:16px;display:flex;gap:16px;align-items:flex-start}
.news-col{flex:1;min-width:0;max-height:calc(100vh - 80px);overflow-y:auto}
.bid-col{width:380px;flex-shrink:0;position:sticky;top:60px;max-height:calc(100vh - 80px);overflow-y:auto}
.date-section{margin-bottom:20px;animation:fadeIn .4s ease}
.date-section.collapsed .date-body{display:none}
.date-section.collapsed .arrow{transform:rotate(-90deg)}
.date-header{display:flex;align-items:center;gap:10px;padding:12px 16px;background:var(--card);border:1px solid #e5e7eb;border-radius:var(--radius) var(--radius) 0 0;cursor:pointer;user-select:none;transition:background .15s}
.date-header:hover{background:#f8fafc}
.date-header h2{font-size:15px;font-weight:700;color:var(--text);flex:1}
.date-count{font-size:11px;color:var(--accent);background:#eff6ff;padding:2px 10px;border-radius:10px;font-weight:600}
.arrow{transition:transform .25s;font-size:11px;color:var(--text2)}
.date-body{background:var(--card);border:1px solid #e5e7eb;border-top:none;border-radius:0 0 var(--radius) var(--radius);padding:10px 12px}
.card{background:var(--bg);border-radius:8px;margin-bottom:8px;display:flex;overflow:hidden;border:1px solid transparent;transition:all .15s}
.card:hover{border-color:#dbeafe;background:#fff;box-shadow:0 4px 16px rgba(0,0,0,.08);transform:translateY(-1px)}
.card-num{min-width:42px;display:flex;align-items:flex-start;justify-content:center;padding:14px 0;font-size:14px;font-weight:800;color:var(--accent);background:linear-gradient(180deg,#eff6ff,#dbeafe)}
.card-body{flex:1;padding:12px 14px 14px 12px;min-width:0}
.card-title{font-size:15px;font-weight:700;margin-bottom:6px;line-height:1.5}
.title-link{color:var(--text);text-decoration:none;transition:color .15s}.title-link:hover{color:var(--accent)}
.card-meta{font-size:11px;color:var(--text2);margin-bottom:6px;display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.badge{display:inline-flex;align-items:center;background:#eff6ff;color:var(--accent);padding:2px 8px;border-radius:6px;font-size:10px;font-weight:600}
.card-summary{font-size:13px;color:var(--text2);line-height:1.7;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.bid-header{display:flex;align-items:center;gap:10px;padding:12px 16px;background:linear-gradient(135deg,#065f46,#059669);color:#fff;border-radius:var(--radius) var(--radius) 0 0;cursor:pointer;user-select:none}
.bid-header h2{font-size:14px;font-weight:700;color:#fff;flex:1}
.bid-count{font-size:11px;background:rgba(255,255,255,.2);color:#fff;padding:2px 10px;border-radius:10px;font-weight:600}
.bid-card .bid-num{background:linear-gradient(180deg,#ecfdf5,#d1fae5);color:var(--green);min-width:34px;font-size:12px;padding:10px 0}
.bid-card .bid-badge{background:#ecfdf5;color:var(--green)}
.bid-card:hover{border-color:#a7f3d0}
.bid-card .card-title{font-size:13px}
.bid-card .card-summary{font-size:12px}
.bid-col .card{margin-bottom:6px}
.bid-col .date-body{padding:8px 10px}
.footer{text-align:center;padding:20px;font-size:11px;color:#9ca3af;border-top:1px solid #e5e7eb;margin-top:16px;clear:both}
@keyframes fadeIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
@media(max-width:860px){.main-layout{flex-direction:column}.bid-col{width:100%;position:static}.bid-card .card-title{font-size:14px}}
.news-col::-webkit-scrollbar,.bid-col::-webkit-scrollbar{width:4px}.news-col::-webkit-scrollbar-thumb,.bid-col::-webkit-scrollbar-thumb{background:#d1d5db;border-radius:4px}.news-col::-webkit-scrollbar-track,.bid-col::-webkit-scrollbar-track{background:transparent}
@media(max-width:500px){.header{padding:20px 14px 16px}.header h1{font-size:22px}.card-num{min-width:32px;font-size:12px;padding:10px 0}.card-body{padding:8px 10px 10px 8px}.card-title{font-size:14px}.date-header{padding:8px 12px}}
</style>
"@

# ====== JS ======
$jsBlock = @"
<script>
function updateTime(){var n=new Date(),bj=new Date(n.getTime()+n.getTimezoneOffset()*60000+28800000),w=['日','一','二','三','四','五','六'],ts=bj.getFullYear()+'-'+('0'+(bj.getMonth()+1)).slice(-2)+'-'+('0'+bj.getDate()).slice(-2)+' 星期'+w[bj.getDay()]+' '+('0'+bj.getHours()).slice(-2)+':'+('0'+bj.getMinutes()).slice(-2)+':'+('0'+bj.getSeconds()).slice(-2);document.getElementById('live-date').textContent=ts;document.title='低空新闻 · '+ts}
updateTime();setInterval(updateTime,1000);
function scrollToDate(d){var s=document.querySelector('.date-section[data-date="'+d+'"]');if(s){s.classList.remove('collapsed');s.scrollIntoView({behavior:'smooth',block:'start'})}}
</script>
"@

# ====== Full HTML ======
$fullHtml = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<link rel="manifest" href="/drone-news/manifest.json">
<meta name="theme-color" content="#0f172a">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="低空经济通">
<link rel="apple-touch-icon" href="/drone-news/icon-192.png">
<title>低空经济通</title>
$style
</head>
<body>
<div class="header">
  <h1>低空经济通</h1>
  <div class="sub"><span id="live-date"></span> · 累计 <span id="live-count">$($allDates.Count)</span> 天</div>
</div>
<div class="tab-bar">$tabHtml</div>
<div class="main-layout">
  <div class="news-col">
    $todaySection
    $existingHtml
  </div>
  <div class="bid-col">
    <div class="date-section">
      <div class="bid-header" onclick="this.parentElement.classList.toggle('collapsed')">
        <h2>📋 无人机招投标</h2>
        <span class="bid-count">$($bidItems.Count)条</span>
        <span class="arrow">▼</span>
      </div>
      <div class="date-body">$bidCards</div>
    </div>
  </div>
</div>
<div class="footer">🚁 低空经济资讯聚合 · 每日自动更新 · 全部内容内嵌本页</div>
$jsBlock
<script>
if('serviceWorker' in navigator){navigator.serviceWorker.register('/drone-news/sw.js')}
</script>
</body>
</html>
"@

Set-Content -Path $outputHtml -Value $fullHtml -Encoding UTF8
Set-Content -Path $docsOutput -Value $fullHtml -Encoding UTF8
Write-Output "Docs: $docsOutput"

# Auto commit & push
try {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    git -C $PSScriptRoot add docs/index.html
    git -C $PSScriptRoot commit -m "Update $(Get-Date -Format 'yyyy-MM-dd HH:mm')" --allow-empty
    git -C $PSScriptRoot push origin master 2>&1 | Out-Null
    Write-Output "Git pushed OK"

# QQ消息推送
$topTitle = ($allItems | Select-Object -First 1).Title
if (-not $topTitle) { $topTitle = "今日暂无新闻" }
$pushScript = Join-Path $PSScriptRoot "push_to_qq.ps1"
if (Test-Path $pushScript) {
    & $pushScript -Title $topTitle -NewsCount $allItems.Count -BidCount $bidItems.Count
}
} catch {
    Write-Output "Git push skipped: $_"
}
