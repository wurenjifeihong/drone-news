const express = require("express");
const crypto = require("crypto");
const axios = require("axios");

const app = express();
app.use(express.json());

const APP_ID = process.env.FEISHU_APP_ID || "";
const APP_SECRET = process.env.FEISHU_APP_SECRET || "";
const OPENAI_KEY = process.env.OPENAI_API_KEY || "";
const VERIFY_TOKEN = process.env.FEISHU_VERIFY_TOKEN || "codex_drone_news";

let tenantToken = null;
let tokenExpire = 0;

// Get Feishu tenant access token
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

// Call OpenAI API
async function chatAI(userMessage) {
  const { data } = await axios.post(
    "https://api.openai.com/v1/chat/completions",
    {
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: "你是低空经济通助手，专注无人机、低空经济、SLAM激光扫描、高斯泼溅点云模型领域。用中文简洁回答。" },
        { role: "user", content: userMessage }
      ],
      max_tokens: 1000
    },
    { headers: { Authorization: `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" } }
  );
  return data.choices[0].message.content;
}

// Reply to Feishu message
async function replyMessage(msgId, content) {
  const token = await getTenantToken();
  await axios.post(
    `https://open.feishu.cn/open-apis/im/v1/messages/${msgId}/reply`,
    { content: JSON.stringify({ text: content }) },
    { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } }
  );
}

// Event callback
app.post("/feishu", async (req, res) => {
  const body = req.body;

  // URL verification
  if (body.type === "url_verification") {
    return res.json({ challenge: body.challenge });
  }

  // Respond immediately (Feishu requires < 3s)
  res.json({ code: 0 });

  // Process message
  try {
    const event = body.event;
    if (event && event.message && event.message.chat_type) {
      const msgType = event.message.message_type;
      let userText = "";
      if (msgType === "text") {
        userText = JSON.parse(event.message.content).text || "";
      }
      if (userText.trim()) {
        const reply = await chatAI(userText);
        await replyMessage(event.message.message_id, reply);
      }
    }
  } catch (e) {
    console.error("Reply error:", e.message);
  }
});

app.get("/", (_, res) => res.send("Feishu Bot Running"));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Bot running on port ${PORT}`));
