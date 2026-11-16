<script setup lang="ts">
import { computed, ref } from 'vue'
import { useData, withBase } from 'vitepress'

type Chapter = { label: string; time: number }

const props = withDefaults(
  defineProps<{
    src: string
    poster: string
    caption?: string
    title?: string
    chapters?: Chapter[]
  }>(),
  {
    caption: '',
    title: '',
    chapters: () => [],
  },
)

type DemoCopy = {
  title: string
  openVideo: string
  playAria: string
  playText: string
  chaptersAria: string
}

const copy: Record<string, DemoCopy> = {
  'zh-CN': {
    title: 'SakuraMedia 产品演示',
    openVideo: '打开演示视频',
    playAria: '播放 45 秒演示视频',
    playText: '播放 45 秒',
    chaptersAria: '演示章节',
  },
  root: {
    title: 'SakuraMedia product demo',
    openVideo: 'Open the demo video',
    playAria: 'Play the 45-second demo video',
    playText: 'Play 45 s',
    chaptersAria: 'Demo chapters',
  },
}

const { localeIndex } = useData()

const text = computed(() => copy[localeIndex.value] ?? copy.root)

const videoTitle = computed(() => props.title || text.value.title)

const video = ref<HTMLVideoElement | null>(null)
const started = ref(false)

const videoUrl = computed(() => withBase(props.src))
const posterUrl = computed(() => withBase(props.poster))

function formatTime(seconds: number) {
  const total = Math.max(0, Math.floor(seconds))
  const minutes = Math.floor(total / 60)
  const rest = total % 60
  return `${minutes}:${rest.toString().padStart(2, '0')}`
}

function startPlayback() {
  const element = video.value
  if (!element) return
  void element.play()
}

function playAt(seconds: number) {
  const element = video.value
  if (!element) return
  const seek = () => {
    element.currentTime = seconds
    void element.play()
  }
  if (element.readyState >= 1) {
    seek()
    return
  }
  element.addEventListener('loadedmetadata', seek, { once: true })
  element.load()
}
</script>

<template>
  <figure class="sm-demo">
    <div class="sm-demo__stage">
      <video
        ref="video"
        class="sm-demo__video"
        :controls="started"
        playsinline
        preload="metadata"
        :poster="posterUrl"
        :aria-label="videoTitle"
        @play="started = true"
      >
        <source :src="videoUrl" type="video/mp4" />
        <a :href="videoUrl">{{ text.openVideo }}</a>
      </video>
      <button
        v-if="!started"
        type="button"
        class="sm-demo__play"
        :aria-label="text.playAria"
        @click="startPlayback"
      >
        <span class="sm-demo__play-icon" aria-hidden="true" />
        <span class="sm-demo__play-text">{{ text.playText }}</span>
      </button>
    </div>
    <div v-if="chapters.length" class="sm-demo__chapters" :aria-label="text.chaptersAria">
      <button
        v-for="chapter in chapters"
        :key="chapter.time"
        type="button"
        class="sm-demo__chapter"
        @click="playAt(chapter.time)"
      >
        <span class="sm-demo__time">{{ formatTime(chapter.time) }}</span>
        {{ chapter.label }}
      </button>
    </div>
    <figcaption v-if="caption" class="sm-demo__caption">
      {{ caption }}
    </figcaption>
  </figure>
</template>

<style scoped>
.sm-demo {
  margin: 0;
}

.sm-demo__stage {
  position: relative;
  overflow: hidden;
  border: 1px solid var(--vp-c-divider);
  border-radius: 16px;
  background: #000;
  box-shadow: 0 18px 48px rgba(0, 0, 0, 0.18);
}

.sm-demo__video {
  display: block;
  width: 100%;
  aspect-ratio: 16 / 10;
  background: #000;
}

.sm-demo__play {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  width: 100%;
  border: 0;
  background: linear-gradient(
    180deg,
    rgba(0, 0, 0, 0.08),
    rgba(0, 0, 0, 0.42)
  );
  color: #fff;
  cursor: pointer;
}

.sm-demo__play:focus-visible {
  outline: 2px solid var(--vp-c-brand-1);
  outline-offset: -4px;
}

.sm-demo__play-icon {
  display: block;
  width: 0;
  height: 0;
  margin-left: 6px;
  border-top: 18px solid transparent;
  border-bottom: 18px solid transparent;
  border-left: 28px solid currentColor;
}

.sm-demo__play-text {
  font-size: 15px;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-shadow: 0 1px 8px rgba(0, 0, 0, 0.45);
}

.sm-demo__chapters {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 14px;
}

.sm-demo__chapter {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 12px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 999px;
  background: var(--vp-c-bg-soft);
  color: var(--vp-c-text-2);
  font-size: 13px;
  line-height: 1.4;
  cursor: pointer;
  transition:
    border-color 0.2s ease,
    color 0.2s ease;
}

.sm-demo__chapter:hover {
  border-color: var(--vp-c-brand-1);
  color: var(--vp-c-text-1);
}

.sm-demo__chapter:focus-visible {
  outline: 2px solid var(--vp-c-brand-1);
  outline-offset: 2px;
}

.sm-demo__time {
  color: var(--vp-c-brand-1);
  font-variant-numeric: tabular-nums;
}

.sm-demo__caption {
  margin-top: 12px;
  color: var(--vp-c-text-3);
  font-size: 13px;
  line-height: 1.6;
  text-align: center;
  text-wrap: pretty;
}

@media (max-width: 640px) {
  .sm-demo__stage {
    border-radius: 12px;
  }

  .sm-demo__play-icon {
    border-top-width: 13px;
    border-bottom-width: 13px;
    border-left-width: 21px;
  }

  .sm-demo__play-text {
    font-size: 13px;
  }

  .sm-demo__chapters {
    flex-wrap: wrap;
    padding-bottom: 0;
  }

  .sm-demo__chapter {
    flex: 0 0 auto;
  }
}
</style>
