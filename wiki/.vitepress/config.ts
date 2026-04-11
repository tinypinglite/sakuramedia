import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'SakuraMedia',
  description: '桌面优先的 SakuraMedia 媒体管理工作台',
  base: '/sakuramedia/',
  lang: 'zh-CN',

  themeConfig: {
    logo: '/brand/sakuramedia-logo.png',
    nav: [
      { text: '指南', link: '/guide/quick-start' },
      { text: 'FAQ', link: '/faq' },
    ],

    sidebar: {
      '/guide/': [
        {
          text: '指南',
          items: [
            { text: '快速开始', link: '/guide/quick-start' },
            { text: '配置说明', link: '/guide/config' },
            { text: '后台任务', link: '/guide/tasks' },
            { text: '进阶部署', link: '/guide/docker' },
            { text: '常用命令', link: '/guide/commands' },
            { text: '常见问题', link: '/faq' },
          ],
        },
      ],
      '/faq': [
        {
          text: '常见问题',
          items: [
            { text: '常见问题', link: '/faq' },
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
      message: 'Released under the GNU GPL v3 License.',
      copyright: 'Copyright © 2024-present SakuraMedia',
    },
  },
})
