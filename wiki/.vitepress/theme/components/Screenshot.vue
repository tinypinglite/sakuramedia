<script setup lang="ts">
import { computed } from 'vue'
import { useData, withBase } from 'vitepress'

type Variant = 'default' | 'narrow' | 'phone'

const props = withDefaults(
  defineProps<{
    src: string
    alt: string
    caption?: string
    variant?: Variant
    zoom?: boolean
    loading?: 'lazy' | 'eager'
  }>(),
  {
    caption: '',
    variant: 'default',
    zoom: true,
    loading: 'lazy',
  },
)

const zoomLabel: Record<string, (alt: string) => string> = {
  'zh-CN': (alt: string) => `查看大图：${alt}`,
  root: (alt: string) => `View full size: ${alt}`,
}

const { localeIndex } = useData()

const zoomTitle = computed(() => (zoomLabel[localeIndex.value] ?? zoomLabel.root)(props.alt))

const url = computed(() => withBase(props.src))
</script>

<template>
  <figure class="sm-shot" :class="`sm-shot--${variant}`">
    <a
      v-if="zoom"
      class="sm-shot__link"
      :href="url"
      target="_blank"
      rel="noopener"
      :title="zoomTitle"
    >
      <img
        class="sm-shot__img"
        :src="url"
        :alt="alt"
        :loading="loading"
        decoding="async"
      />
    </a>
    <img
      v-else
      class="sm-shot__img"
      :src="url"
      :alt="alt"
      :loading="loading"
      decoding="async"
    />
    <figcaption v-if="caption" class="sm-shot__caption">
      {{ caption }}
    </figcaption>
  </figure>
</template>

<style scoped>
.sm-shot {
  margin: 24px 0;
}

.sm-shot__link {
  display: block;
  cursor: zoom-in;
}

.sm-shot__img {
  display: block;
  width: 100%;
  height: auto;
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  background: var(--vp-c-bg-soft);
  transition: border-color 0.2s ease;
}

.sm-shot__link:hover .sm-shot__img,
.sm-shot__link:focus-visible .sm-shot__img {
  border-color: var(--vp-c-brand-1);
}

.sm-shot__link:focus-visible {
  outline: 2px solid var(--vp-c-brand-1);
  outline-offset: 4px;
}

.sm-shot__caption {
  margin-top: 10px;
  color: var(--vp-c-text-3);
  font-size: 13px;
  line-height: 1.6;
  text-align: center;
  text-wrap: pretty;
}

.sm-shot--narrow {
  max-width: 420px;
  margin-inline: auto;
}

.sm-shot--phone {
  max-width: 240px;
  margin-inline: auto;
}

.sm-shot--phone .sm-shot__img {
  border-radius: 24px;
}
</style>
