const cloud = require('wx-server-sdk')
cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })

exports.main = async () => {
  try {
    // 从外部 API 获取新闻数据
    const https = require('https')
    const data = await new Promise((resolve, reject) => {
      https.get('https://your-api-domain.com/news.json', res => {
        let body = ''
        res.on('data', chunk => body += chunk)
        res.on('end', () => resolve(JSON.parse(body)))
      }).on('error', reject)
    })
    return data
  } catch (e) {
    // 返回缓存数据
    const db = cloud.database()
    const cache = await db.collection('news_cache')
      .orderBy('date', 'desc').limit(1).get()
    return cache.data[0] ? cache.data[0].items : []
  }
}
