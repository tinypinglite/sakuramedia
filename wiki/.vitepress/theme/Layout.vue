<script setup lang="ts">
import { computed } from 'vue'
import { useData, withBase } from 'vitepress'
import DefaultTheme from 'vitepress/theme'
import DemoVideo from './components/DemoVideo.vue'

type Chapter = { label: string; time: number }

type HomeCopy = {
  demoEyebrow: string
  demoTitle: string
  demoNote: string
  demoVideoTitle: string
  demoCaption: string
  chapters: Chapter[]
  storyTitle: string
  storyBody: string
  storyLink: string
  featuresTitle: string
  previewTitle: string
  previewAlt: string
  previewCaption: string
  previewLink: string
}

const copy: Record<string, HomeCopy> = {
  'zh-CN': {
    demoEyebrow: '产品演示 · 45 秒',
    demoTitle: '看一遍完整流程',
    demoNote: '演示数据，封面与缩略图已虚化；视频无旁白。',
    demoVideoTitle: 'SakuraMedia 产品演示',
    demoCaption: '从概览、发现、详情和播放，到缩略图、以图搜图、切片与 PornBox。',
    chapters: [
      { label: '概览', time: 0 },
      { label: '发现', time: 4.5 },
      { label: '详情', time: 9.5 },
      { label: '播放器', time: 14.5 },
      { label: '以图搜图', time: 22.5 },
      { label: '切片', time: 26.5 },
      { label: 'PornBox', time: 32 },
    ],
    storyTitle: '这部影片里，你真正想留下什么？',
    storyBody:
      '一部喜欢的作品，一个舍不得的画面，或是想好好保存的几分钟。聊聊我为什么做这个项目，以及我理解的收藏。',
    storyLink: '读读 SakuraMedia 的初衷',
    featuresTitle: '功能一览',
    previewTitle: '界面预览',
    previewAlt: 'SakuraMedia 界面预览',
    previewCaption: '截图使用演示数据，封面与缩略图已虚化。',
    previewLink: '从使用手册开始 →',
  },
  root: {
    demoEyebrow: 'Product demo · 45 seconds',
    demoTitle: 'Watch the whole flow once',
    demoNote: 'Demo data: posters and thumbnails are blurred, and the video has no narration.',
    demoVideoTitle: 'SakuraMedia product demo',
    demoCaption:
      'From overview, discovery, details and playback, to thumbnails, image search, clips and PornBox.',
    chapters: [
      { label: 'Overview', time: 0 },
      { label: 'Discovery', time: 4.5 },
      { label: 'Details', time: 9.5 },
      { label: 'Player', time: 14.5 },
      { label: 'Image search', time: 22.5 },
      { label: 'Clips', time: 26.5 },
      { label: 'PornBox', time: 32 },
    ],
    storyTitle: 'What do you really want to keep from this movie?',
    storyBody:
      'A movie you love, a frame you cannot let go of, or a few minutes worth keeping properly. On why I built this project, and what collecting means to me.',
    storyLink: 'Read why SakuraMedia exists',
    featuresTitle: 'Features at a glance',
    previewTitle: 'Interface preview',
    previewAlt: 'SakuraMedia interface preview',
    previewCaption: 'Screenshots use demo data; posters and thumbnails are blurred.',
    previewLink: 'Start with the user manual →',
  },
}

const { localeIndex } = useData()

const text = computed(() => copy[localeIndex.value] ?? copy.root)

// 英文站用 readme-en/ 下的英文截图与英文演示视频；中文站用 readme/ 下的中文资源。
const isEnglish = computed(() => localeIndex.value === 'root')

const previewImage = computed(() =>
  withBase(
    isEnglish.value
      ? '/images/readme-en/home-hero.jpg'
      : '/images/readme/home-hero.jpg',
  ),
)

const demoVideoSource = computed(() =>
  isEnglish.value
    ? '/videos/sakuramedia-demo-en.mp4'
    : '/videos/sakuramedia-demo.mp4',
)

const demoPoster = computed(() =>
  isEnglish.value
    ? '/images/readme-en/desktop-overview.png'
    : '/images/readme/desktop-overview.png',
)

const storyLink = computed(() =>
  withBase(
    localeIndex.value === 'root'
      ? '/guide/collection-strategy'
      : '/zh-CN/guide/collection-strategy',
  ),
)

const manualLink = computed(() =>
  withBase(localeIndex.value === 'root' ? '/manual/' : '/zh-CN/manual/'),
)
</script>

<template>
  <DefaultTheme.Layout>
    <template #home-features-before>
      <section id="demo" class="demo" aria-labelledby="demo-title">
        <div class="demo__head">
          <div>
            <p class="demo__eyebrow">{{ text.demoEyebrow }}</p>
            <h2 id="demo-title" class="demo__title">{{ text.demoTitle }}</h2>
          </div>
          <p class="demo__note">{{ text.demoNote }}</p>
        </div>
        <DemoVideo
          :src="demoVideoSource"
          :poster="demoPoster"
          :chapters="text.chapters"
          :title="text.demoVideoTitle"
          :caption="text.demoCaption"
        />
      </section>

      <section class="story" aria-labelledby="story-title">
        <a class="story-card" :href="storyLink">
          <h2 id="story-title">{{ text.storyTitle }}</h2>
          <p>{{ text.storyBody }}</p>
          <span class="story-link">{{ text.storyLink }} <span aria-hidden="true">→</span></span>
        </a>
      </section>

      <h2 class="features-title">{{ text.featuresTitle }}</h2>
    </template>

    <template #home-features-after>
      <section class="preview" aria-labelledby="preview-title">
        <h2 id="preview-title" class="preview__title">{{ text.previewTitle }}</h2>
        <img
          class="preview__img"
          :src="previewImage"
          :alt="text.previewAlt"
          width="2200"
          height="1237"
          loading="lazy"
          decoding="async"
        />
        <p class="preview__caption">
          {{ text.previewCaption }}
          <a :href="manualLink">{{ text.previewLink }}</a>
        </p>
      </section>
    </template>
  </DefaultTheme.Layout>
</template>

<style scoped>
.demo,
.story,
.preview,
.features-title {
  margin: 0 auto 32px;
  padding: 0 24px;
  max-width: 1280px;
}

.demo {
  padding-top: 8px;
}

.demo__head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 24px;
  margin-bottom: 20px;
}

.demo__eyebrow {
  color: var(--vp-c-brand-1);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.08em;
}

.demo__title {
  margin-top: 4px;
  color: var(--vp-c-text-1);
  font-size: 24px;
  font-weight: 600;
  line-height: 1.5;
}

.demo__note {
  color: var(--vp-c-text-3);
  font-size: 13px;
  line-height: 1.6;
  text-align: right;
}

.story-card {
  display: block;
  padding: 28px;
  border: 1px solid transparent;
  border-radius: 16px;
  background: var(--vp-c-brand-soft);
  color: var(--vp-c-text-1);
  transition: border-color 0.2s;
}

.story-card:hover {
  border-color: var(--vp-c-brand-1);
}

.story-card:focus-visible {
  outline: 2px solid var(--vp-c-brand-1);
  outline-offset: 4px;
}

.story-card h2 {
  font-size: 24px;
  font-weight: 600;
  line-height: 1.5;
  text-wrap: pretty;
}

.story-card p {
  margin: 12px 0 20px;
  max-width: 760px;
  color: var(--vp-c-text-2);
  font-size: 16px;
  line-height: 1.8;
}

.story-link {
  color: var(--vp-c-brand-1);
  font-size: 15px;
  font-weight: 600;
}

.features-title,
.preview__title {
  margin-bottom: 20px;
  color: var(--vp-c-text-1);
  font-size: 24px;
  font-weight: 600;
  line-height: 1.5;
}

.preview {
  margin-top: 8px;
  margin-bottom: 48px;
}

.preview__img {
  display: block;
  width: 100%;
  height: auto;
  border: 1px solid var(--vp-c-divider);
  border-radius: 16px;
  background: var(--vp-c-bg-soft);
}

.preview__caption {
  margin-top: 12px;
  color: var(--vp-c-text-3);
  font-size: 13px;
  line-height: 1.6;
  text-align: center;
}

.preview__caption a {
  color: var(--vp-c-brand-1);
  font-weight: 600;
  white-space: nowrap;
}

@media (min-width: 640px) {
  .demo,
  .story,
  .preview,
  .features-title {
    padding: 0 48px;
  }

  .story-card {
    padding: 32px 40px;
  }

  .story-card h2 {
    font-size: 28px;
  }
}

@media (min-width: 960px) {
  .demo,
  .story,
  .preview,
  .features-title {
    padding: 0 64px;
  }
}

@media (max-width: 639px) {
  .demo__head {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }

  .demo__note {
    text-align: left;
  }
}
</style>
