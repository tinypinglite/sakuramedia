import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'SakuraMedia',
  description: 'NAS 媒体管理工作台',
  base: '/sakuramedia/',
  lang: 'zh-CN',

  themeConfig: {
    nav: [
      { text: '指南', link: '/guide/introduction' },
      { text: 'API', link: '/api/overview' },
      { text: 'FAQ', link: '/faq' },
    ],

    sidebar: {
      '/guide/': [
        {
          text: '指南',
          items: [
            { text: '什么是 SakuraMedia', link: '/guide/introduction' },
            { text: '快速开始', link: '/guide/quick-start' },
            { text: 'Docker 部署', link: '/guide/docker' },
            { text: '常用命令', link: '/guide/commands' },
          ],
        },
      ],
      '/api/': [
        {
          text: 'API 参考',
          items: [
            { text: '总览', link: '/api/overview' },
            { text: '设计约定', link: '/api/conventions' },
          ],
        },
        {
          text: '媒体播放',
          items: [
            { text: '播放 API', link: '/api/playback/media' },
          ],
        },
        {
          text: '以图搜图',
          items: [
            { text: '图片搜索 API', link: '/api/discovery/image-search' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/tinypinglite/sakuramedia' },
    ],

    search: {
      provider: 'local',
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2024-present SakuraMedia',
    },
  },
})
