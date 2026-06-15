const API_BASE = 'https://your-api-domain.com'

function fetchNews() {
  return new Promise((resolve, reject) => {
    wx.request({
      url: API_BASE + '/news.json',
      success: res => resolve(res.data),
      fail: reject
    })
  })
}

module.exports = { fetchNews, API_BASE }
