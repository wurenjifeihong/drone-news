const express = require("express");
const axios = require("axios");

const app = express();
app.use(express.json());

const APP_ID = process.env.FEISHU_APP_ID || "";
const APP_SECRET = process.env.FEISHU_APP_SECRET || "";
const OPENAI_KEY = process.env.OPENAI_API_KEY || "";
const GITHUB_TOKEN = process.env.GITHUB_TOKEN || "";
const GITHUB_REPO = "wurenjifeihong/drone-news";

let tenantToken = null, tokenExpire = 0;

async function getTenantToken() {
  if (tenantToken && Date.now() < tokenExpire) return tenantToken;
  const { data } = await axios.post(
    "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
    { app_id: APP_ID, app_secret: APP_SECRET }
  );
  tenantToken = data.tenant_access_token;
  tokenExpire = Date.now() + (data.expire - 300) * 1000;
  return tenantToken;
}

// Reply to Feishu message (supports long messages via chunks)
async function replyMessage(msgId, content) {
  const token = await getTenantToken();
  const chunks = splitLongMessage(content);
  for (const chunk of chunks) {
    await axios.post(
      `https://open.feishu.cn/open-apis/im/v1/messages/${msgId}/reply`,
      { content: JSON.stringify({ text: chunk }) },
      { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } }
    );
  }
}

function splitLongMessage(text, maxLen = 4000) {
  if (text.length <= maxLen) return [text];
  const chunks = [];
  let remaining = text;
  while (remaining.length > maxLen) {
    let cut = remaining.lastIndexOf("\n", maxLen);
    if (cut < 0 || cut < maxLen / 2) cut = maxLen;
    chunks.push(remaining.substring(0, cut));
    remaining = remaining.substring(cut);
  }
  if (remaining) chunks.push(remaining);
  return chunks;
}

// Trigger GitHub Actions to refresh news
async function createCommandIssue(command) {
  if (!GITHUB_TOKEN) return "GitHub Token 未配置。";
  try {
    await axios.post(
      `https://api.github.com/repos/${GITHUB_REPO}/issues`,
      {
        title: `[飞书] ${command}`,
        body: `<!--cmd:${command}-->\n来自飞书的命令: ${command}`,
        labels: ["feishu-command"]
      },
      { headers: { Authorization: `Bearer ${GITHUB_TOKEN}`, Accept: "application/vnd.github+json" } }
    );
    return `✅ 命令已发送，电脑端正在执行...(${command})`;
  } catch (e) {
    return `❌ 发送失败: ${e.response?.data?.message || e.message}`;
  }
}

async function triggerNewsUpdate() {
  if (!GITHUB_TOKEN) return "GitHub Token 未配置，无法触发更新。";
  try {
    await axios.post(
      `https://api.github.com/repos/${GITHUB_REPO}/dispatches`,
      { event_type: "update-news" },
      { headers: { Authorization: `Bearer ${GITHUB_TOKEN}`, Accept: "application/vnd.github+json" } }
    );
    return "✅ 已触发新闻更新，几分钟后刷新页面即可看到最新内容。";
  } catch (e) {
    return `❌ 触发失败: ${e.response?.data?.message || e.message}`;
  }
}

// Check latest news
async function checkNewsStatus() {
  try {
    const { data } = await axios.get(
      `https://api.github.com/repos/${GITHUB_REPO}/commits?per_page=1`,
      { headers: { Accept: "application/vnd.github+json" } }
    );
    const commit = data[0];
    const date = new Date(commit.commit.author.date);
    const timeAgo = Math.floor((Date.now() - date.getTime()) / 60000);
    return `📡 最新更新: ${timeAgo}分钟前 (${date.toLocaleString("zh-CN", { timeZone: "Asia/Shanghai" })})\n🔗 https://wurenjifeihong.github.io/drone-news/`;
  } catch {
    return "无法获取更新状态。";
  }
}

// Main AI chat with Codex-like system prompt
async function chatWithCodex(userMessage, conversationHistory) {
  const systemPrompt = `你是低空经济通的智能助手，运行在飞书平台上。你的主人通过飞书跟你聊天、下达命令。

## 你的身份
- 你是基于 GPT-4o 的 AI 助手，专精无人机、低空经济、SLAM激光扫描、高斯泼溅点云模型领域
- 你负责维护 https://wurenjifeihong.github.io/drone-news/ （低空经济通每日资讯网站）
- 风格：简洁、直接、友好，中文回答

## 你的能力
1. **查询新闻状态**：调用 check_news_status 函数
2. **触发新闻更新**：调用 trigger_news_update 函数（让服务器重新抓取新闻）
3. **回答专业问题**：无人机、低空经济、SLAM、高斯泼溅、点云模型等
4. **日常聊天**：可以闲聊、答疑

## 项目背景
- 每日早上6:00自动抓取无人机新闻 + 招投标信息
- 左侧栏"无人机新闻"：综合资讯（无人机、低空经济、大疆、航拍、巡检、SLAM、高斯泼溅、点云）
- 右侧栏"无人机招投标"：福建地区招投标 + SLAM/高斯泼溅/点云
- 网站已做成PWA，可安装到手机桌面

## 规则
- 回答简洁，不超过300字（除非用户要求详细）
- 涉及代码/文件操作时，友好说明需要通过电脑端 Codex 执行
- 当用户说"更新新闻"或"刷新"时，调用 trigger_news_update
- 当用户说"状态"或"最新"时，调用 check_news_status`;

  const messages = [{ role: "system", content: systemPrompt }];
  if (conversationHistory && conversationHistory.length > 0) {
    messages.push(...conversationHistory);
  }
  messages.push({ role: "user", content: userMessage });

  const functions = [
    {
      name: "trigger_news_update",
      description: "触发新闻更新，重新抓取最新无人机资讯",
      parameters: { type: "object", properties: {}, required: [] }
    },
    {
      name: "check_news_status",
      description: "查询新闻网站最新更新状态",
      parameters: { type: "object", properties: {}, required: [] }
    }
  ];

  const { data } = await axios.post(
    "https://api.openai.com/v1/chat/completions",
    {
      model: "gpt-4o-mini",
      messages,
      functions,
      function_call: "auto",
      max_tokens: 1200,
      temperature: 0.7
    },
    { headers: { Authorization: `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" } }
  );

  const choice = data.choices[0];
  
  // Handle function calls
  if (choice.message.function_call) {
    const fc = choice.message.function_call;
    let result = "";
    if (fc.name === "trigger_news_update") result = await triggerNewsUpdate();
    else if (fc.name === "check_news_status") result = await checkNewsStatus();
    
    // Send function result back to AI for natural response
    const followUp = await axios.post(
      "https://api.openai.com/v1/chat/completions",
      {
        model: "gpt-4o-mini",
        messages: [
          ...messages,
          choice.message,
          { role: "function", name: fc.name, content: result }
        ],
        max_tokens: 500,
        temperature: 0.7
      },
      { headers: { Authorization: `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" } }
    );
    return followUp.data.choices[0].message.content;
  }

  return choice.message.content;
}

// Simple in-memory conversation store (per chat)
const conversations = new Map();

app.post("/feishu", async (req, res) => {
  const body = req.body;

  if (body.type === "url_verification") {
    return res.json({ challenge: body.challenge });
  }

  res.json({ code: 0 });

  try {
    const event = body.event || body.header;
    if (!event || !event.message) return;

    const chatId = event.message.chat_id;
    const msgType = event.message.message_type;
    let userText = "";

    if (msgType === "text") {
      userText = JSON.parse(event.message.content).text || "";
    }

    if (!userText.trim()) return;

    // Get recent conversation context (last 5 exchanges)
    let history = conversations.get(chatId) || [];
    const recentHistory = history.slice(-10);

    const reply = await chatWithCodex(userText, recentHistory);

    // Store conversation
    history.push(
      { role: "user", content: userText },
      { role: "assistant", content: reply }
    );
    if (history.length > 20) history = history.slice(-20);
    conversations.set(chatId, history);

    await replyMessage(event.message.message_id, reply);

  } catch (e) {
    console.error("Error:", e.message);
    try {
      await replyMessage(event.message.message_id, "抱歉，出了点问题，请稍后再试。");
    } catch {}
  }
});

app.get("/", (_, res) => res.send("低空经济通 Feishu Bot Running ✅"));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Bot running on port ${PORT}`));
