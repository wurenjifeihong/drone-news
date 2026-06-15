const app = getApp()
Page({
  data: { newsList: [], dateStr: '', weekday: '', updateTime: '' },

  onLoad() { this.loadNews() },
  onPullDownRefresh() { this.loadNews(() => wx.stopPullDownRefresh()) },

  loadNews(cb) {
    const now = new Date()
    const wd = ['日','一','二','三','四','五','六']
    this.setData({
      dateStr: `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`,
      weekday: wd[now.getDay()],
      updateTime: `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`
    })

    // 尝试云函数 → API → 演示数据 三级回退
    if (typeof wx.cloud !== 'undefined') {
      this.loadFromCloud(cb)
    } else {
      this.loadFromApi(cb)
    }
  },

  loadFromCloud(cb) {
    wx.cloud.callFunction({ name: 'fetchNews' }).then(res => {
      if (res.result && res.result.length) {
        this.setData({ newsList: res.result })
        if (cb) cb()
      } else {
        this.loadFromApi(cb)
      }
    }).catch(() => this.loadFromApi(cb))
  },

  loadFromApi(cb) {
    wx.request({
      url: app.globalData.apiBase + '/news.json',
      success: res => {
        if (res.data && res.data.length) {
          this.setData({ newsList: res.data })
        } else {
          this.setDemoData()
        }
      },
      fail: () => this.setDemoData(),
      complete: () => { if (cb) cb() }
    })
  },

  setDemoData() {
    this.setData({
      newsList: [
        {Title:"影石、大疆的无人机影像战争,比\"外卖大战\"还惨烈",Source:"36氪",Time:"20分钟前",Summary:"影石和大疆都是从垂直细分赛道切入、靠爆款打穿全球的中国消费硬件出海标杆,影石从全景相机切入击退了GoPro,大疆则精准填补了消费级无人机市场的空窗期。",Image:"",Link:"https://36kr.com/p/3853667333903362"},
        {Title:"和平区无人机表演为\"东北超\"赛事助威",Source:"同花顺",Time:"44分钟前",Summary:"据沈阳市人民政府消息,6月13日晚,和平区文旅局在沈水湾公园举办无人机编队灯光表演,以\"空、天、水、岸\"四位一体的沉浸式光影秀,为赛事助威。",Image:"",Link:"http://news.10jqka.com.cn/20260615/c677450909.shtml"},
        {Title:"云南出台方案拓展低空经济应用场景",Source:"同花顺",Time:"18小时前",Summary:"云南省发布低空经济发展方案,明确打造无人机物流、低空旅游、航空运动等应用场景,致力于建设低空经济产业发展新高地。",Image:"",Link:"http://news.10jqka.com.cn/20260614/c677446192.shtml"},
        {Title:"大疆、影石全线降价!\"神仙\"打架为哪般?",Source:"快资讯",Time:"13小时前",Summary:"持续大幅降价压缩企业产品毛利,两家企业盈利空间承压,叠加激烈市场竞争,产品品控、售后服务配套是否会出现短板引发关注。",Image:"",Link:""},
        {Title:"大疆和影石,正在终结GoPro时代",Source:"快资讯",Time:"16小时前",Summary:"此后,大疆在全球市场份额逐渐超过GoPro。据久谦咨询数据,2024年,大疆通过Osmo Action 4带动高端产品出货,收入份额从2023年的约8%提升至44%。",Image:"",Link:""},
        {Title:"第十届全国青少年无人机大赛辽宁省赛在朝阳启幕",Source:"东北新闻网",Time:"2小时前",Summary:"全国青少年无人机大赛是纳入教育部中小学生竞赛白名单的国家级权威航空科创赛事,第十届辽宁省赛由中国航空学会主办。",Image:"",Link:""},
        {Title:"俄军上百架无人机狂炸乌克兰全境",Source:"凤凰网",Time:"15分钟前",Summary:"俄军动用大量无人机对乌克兰境内多处核心区域发起打击,彻底打破了此前的停火静默状态,乌克兰方面对此提出强烈控诉。",Image:"",Link:"https://jx.ifeng.com/c/8tvo1g2maD7"},
        {Title:"泰州姜堰启用无人机巡检特种设备",Source:"同花顺",Time:"23小时前",Summary:"破解高处安全监管难题,泰州姜堰区运用无人机对特种设备进行高空巡检,有效提升了安全监管效率和覆盖范围。",Image:"",Link:"http://news.10jqka.com.cn/20260614/c677445106.shtml"}
      ]
    })
  },

  openDetail(e) {
    const item = this.data.newsList[e.currentTarget.dataset.id]
    wx.navigateTo({
      url: '/pages/detail/detail?title=' + encodeURIComponent(item.Title || '') +
           '&source=' + encodeURIComponent(item.Source || '') +
           '&time=' + encodeURIComponent(item.Time || '') +
           '&summary=' + encodeURIComponent(item.Summary || '') +
           '&image=' + encodeURIComponent(item.Image || '') +
           '&link=' + encodeURIComponent(item.Link || '')
    })
  }
})
