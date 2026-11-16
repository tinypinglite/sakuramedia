import { defineConfig } from 'vitepress'

const zhNav = [
  { text: '开始使用', link: '/zh-CN/guide/introduction' },
  { text: '使用手册', link: '/zh-CN/manual/' },
  { text: '设计理念', link: '/zh-CN/guide/collection-strategy' },
]

const enNav = [
  { text: 'Getting started', link: '/guide/introduction' },
  { text: 'User manual', link: '/manual/' },
  { text: 'Design', link: '/guide/collection-strategy' },
]

const zhSidebar = [
  {
    text: '开始使用',
    collapsed: false,
    items: [
      { text: '介绍', link: '/zh-CN/guide/introduction' },
      { text: '快速开始', link: '/zh-CN/guide/quick-start' },
      { text: '推荐插件', link: '/zh-CN/guide/plugins' },
      { text: '配置说明', link: '/zh-CN/guide/config' },
      { text: '后台任务', link: '/zh-CN/guide/tasks' },
      { text: '媒体存储迁移', link: '/zh-CN/guide/media-storage-transfer' },
      { text: '常用命令', link: '/zh-CN/guide/commands' },
      { text: '常见问题', link: '/zh-CN/faq' },
      { text: '插件开发', link: '/zh-CN/guide/plugin-development' },
    ],
  },
  {
    text: '使用手册',
    collapsed: false,
    items: [
      { text: '阅读导航', link: '/zh-CN/manual/' },
      {
        text: '入门',
        collapsed: false,
        items: [
          { text: '认识系统', link: '/zh-CN/manual/concepts' },
          { text: '获得第一部影片', link: '/zh-CN/manual/first-movie' },
          { text: '导入已有资源', link: '/zh-CN/manual/import' },
        ],
      },
      {
        text: '日常使用',
        collapsed: false,
        items: [
          { text: '发现与女优订阅', link: '/zh-CN/manual/discover' },
          { text: '订阅与下载进度', link: '/zh-CN/manual/subscriptions' },
          { text: '开始观看', link: '/zh-CN/manual/playback' },
          { text: '收藏与整理', link: '/zh-CN/manual/collections' },
        ],
      },
      {
        text: '进阶使用',
        collapsed: true,
        items: [
          { text: '媒体库管理', link: '/zh-CN/manual/media-management' },
          { text: '以图搜图', link: '/zh-CN/manual/image-search' },
          { text: 'PornBox 与普通视频', link: '/zh-CN/guide/videos' },
        ],
      },
    ],
  },
  {
    text: '设计理念',
    collapsed: true,
    items: [
      { text: '为什么做 SakuraMedia', link: '/zh-CN/guide/collection-strategy' },
      { text: '从喜欢的画面开始看', link: '/zh-CN/guide/watch-from-a-frame' },
      { text: '有空的时候，想看的已经在了', link: '/zh-CN/guide/waiting-for-a-movie' },
    ],
  },
]

const enSidebar = [
  {
    text: 'Getting started',
    collapsed: false,
    items: [
      { text: 'Introduction', link: '/guide/introduction' },
      { text: 'Quick start', link: '/guide/quick-start' },
      { text: 'Recommended plugins', link: '/guide/plugins' },
      { text: 'Configuration', link: '/guide/config' },
      { text: 'Background tasks', link: '/guide/tasks' },
      { text: 'Media storage transfer', link: '/guide/media-storage-transfer' },
      { text: 'Common commands', link: '/guide/commands' },
      { text: 'FAQ', link: '/faq' },
      { text: 'Plugin development', link: '/guide/plugin-development' },
    ],
  },
  {
    text: 'User manual',
    collapsed: false,
    items: [
      { text: 'Reading guide', link: '/manual/' },
      {
        text: 'Getting started',
        collapsed: false,
        items: [
          { text: 'Understanding the system', link: '/manual/concepts' },
          { text: 'Getting your first movie', link: '/manual/first-movie' },
          { text: 'Importing existing files', link: '/manual/import' },
        ],
      },
      {
        text: 'Daily use',
        collapsed: false,
        items: [
          { text: 'Discovery and actor subscriptions', link: '/manual/discover' },
          { text: 'Subscriptions and download progress', link: '/manual/subscriptions' },
          { text: 'Start watching', link: '/manual/playback' },
          { text: 'Collections and organizing', link: '/manual/collections' },
        ],
      },
      {
        text: 'Advanced use',
        collapsed: true,
        items: [
          { text: 'Media library management', link: '/manual/media-management' },
          { text: 'Image search', link: '/manual/image-search' },
          { text: 'PornBox and regular videos', link: '/guide/videos' },
        ],
      },
    ],
  },
  {
    text: 'Design',
    collapsed: true,
    items: [
      { text: 'Why SakuraMedia', link: '/guide/collection-strategy' },
      { text: 'Start from a frame you love', link: '/guide/watch-from-a-frame' },
      { text: 'When you are free, it is already there', link: '/guide/waiting-for-a-movie' },
    ],
  },
]

const zhThemeConfig = {
  nav: zhNav,
  sidebar: zhSidebar,
  footer: {
    message: 'Released under the GNU GPL v3 License.',
    copyright: 'Copyright © 2024-present SakuraMedia',
  },
}

const enThemeConfig = {
  nav: enNav,
  sidebar: enSidebar,
  footer: {
    message: 'Released under the GNU GPL v3 License.',
    copyright: 'Copyright © 2024-present SakuraMedia',
  },
}

const zhSearchTranslations = {
  button: {
    buttonText: '搜索',
    buttonAriaLabel: '搜索',
  },
  modal: {
    displayDetails: '显示详细列表',
    resetButtonTitle: '重置搜索条件',
    backButtonTitle: '返回上一处',
    noResultsText: '没有找到结果：',
    footer: {
      selectText: '选择',
      selectKeyAriaLabel: '回车键',
      navigateText: '切换',
      navigateUpKeyAriaLabel: '上箭头',
      navigateDownKeyAriaLabel: '下箭头',
      closeText: '关闭',
      closeKeyAriaLabel: 'Esc 键',
    },
  },
}

const enSearchTranslations = {
  button: {
    buttonText: 'Search',
    buttonAriaLabel: 'Search',
  },
  modal: {
    displayDetails: 'Display detailed list',
    resetButtonTitle: 'Reset search criteria',
    backButtonTitle: 'Back to previous location',
    noResultsText: 'No results for',
    footer: {
      selectText: 'to select',
      selectKeyAriaLabel: 'enter key',
      navigateText: 'to navigate',
      navigateUpKeyAriaLabel: 'up arrow',
      navigateDownKeyAriaLabel: 'down arrow',
      closeText: 'to close',
      closeKeyAriaLabel: 'escape key',
    },
  },
}

export default defineConfig({
  title: 'SakuraMedia',
  description: 'A desktop-first media library workbench for SakuraMedia',
  base: '/sakuramedia/',
  lang: 'en',

  locales: {
    root: {
      label: 'English',
      lang: 'en',
      description: 'A desktop-first media library workbench for SakuraMedia',
      themeConfig: enThemeConfig,
    },
    'zh-CN': {
      label: '简体中文',
      lang: 'zh-CN',
      description: '桌面优先的 SakuraMedia 媒体管理工作台',
      themeConfig: zhThemeConfig,
    },
  },

  themeConfig: {
    logo: '/brand/sakuramedia-logo.png',

    socialLinks: [
      { icon: 'github', link: 'https://github.com/tinypinglite/sakuramedia' },
    ],

    search: {
      provider: 'local',
      options: {
        locales: {
          root: { translations: enSearchTranslations },
          'zh-CN': { translations: zhSearchTranslations },
        },
      },
    },
  },
})
