<script setup lang="ts">
withDefaults(defineProps<{ columns?: number }>(), {
  columns: 2,
})
</script>

<template>
  <div class="sm-shot-grid" :style="{ '--sm-columns': columns }">
    <slot />
  </div>
</template>

<style scoped>
.sm-shot-grid {
  display: grid;
  grid-template-columns: repeat(var(--sm-columns, 2), minmax(0, 1fr));
  gap: 16px;
  align-items: start;
  margin: 24px 0;
}

.sm-shot-grid :deep(.sm-shot) {
  margin: 0;
}

@media (max-width: 640px) {
  .sm-shot-grid {
    grid-template-columns: 1fr;
  }
}
</style>
