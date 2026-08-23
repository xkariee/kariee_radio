<script setup lang="ts">
import { computed } from 'vue'
import Icon from './Icon.vue'

const props = withDefaults(
  defineProps<{
    src?: string | null
    hue?: number
    size?: number
    radius?: number
    icon?: string
  }>(),
  { src: null, hue: 172, size: 40, radius: 6, icon: 'music' },
)

const style = computed(() => ({
  width: `${props.size}px`,
  height: `${props.size}px`,
  borderRadius: `${props.radius}px`,
  background: props.src
    ? undefined
    : `linear-gradient(155deg, hsl(${props.hue} 70% 28%), hsl(${(props.hue + 40) % 360} 60% 13%))`,
  boxShadow: props.size > 60 ? '0 12px 28px -10px rgba(0, 0, 0, 0.6)' : undefined,
}))
</script>

<template>
  <div class="cover" :style="style">
    <img v-if="src" :src="src" alt="" />
    <Icon v-else :name="icon" :size="Math.max(12, size * 0.4)" />
  </div>
</template>

<style scoped>
.cover {
  position: relative;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  color: rgba(255, 255, 255, 0.6);
  border: 1px solid rgba(255, 255, 255, 0.08);
  transition: box-shadow 0.15s var(--ease);
}

.cover::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(155deg, rgba(255, 255, 255, 0.12), transparent 45%);
  pointer-events: none;
}

.cover img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
</style>
