import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'SakuraMedia',
  description: '一站式Jav媒体管理系统',
  base: '/sakuramedia/',
  lang: 'zh-CN',

  themeConfig: {
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
            { text: 'Docker 部署', link: '/guide/docker' },
            { text: '常用命令', link: '/guide/commands' },
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
