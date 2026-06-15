Page({
  data: { title: '', source: '', time: '', summary: '', image: '', link: '' },
  onLoad(options) {
    this.setData({
      title: decodeURIComponent(options.title || ''),
      source: decodeURIComponent(options.source || ''),
      time: decodeURIComponent(options.time || ''),
      summary: decodeURIComponent(options.summary || ''),
      image: decodeURIComponent(options.image || ''),
      link: decodeURIComponent(options.link || '')
    })
  },
  openLink() {
    if (!this.data.link) {
      wx.showToast({ title: '暂无原文链接', icon: 'none' })
      return
    }
    wx.setClipboardData({
      data: this.data.link,
      success: () => wx.showToast({ title: '链接已复制，请到浏览器打开', icon: 'success' })
    })
  }
})
