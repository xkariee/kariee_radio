<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import Icon from './Icon.vue'

const props = withDefaults(
  defineProps<{
    src?: string | null
    // Tried first (e.g. a high-res YouTube thumbnail that might not exist), `src` is the fallback.
    hiSrc?: string | null
    hue?: number
    size?: number | 'fill'
    radius?: number
    icon?: string
  }>(),
  { src: null, hiSrc: null, hue: 172, size: 40, radius: 6, icon: 'music' },
)

const useHi = ref(true)
watch(
  () => props.hiSrc,
  () => (useHi.value = true),
)

const shown = computed(() => (props.hiSrc && useHi.value ? props.hiSrc : props.src))

// YouTube serves a 120px grey placeholder (not an error) when maxres doesn't exist.
function onLoad(e: Event) {
  const img = e.target as HTMLImageElement
  if (shown.value === props.hiSrc && img.naturalWidth <= 120) useHi.value = false
}

function onError() {
  if (shown.value === props.hiSrc) useHi.value = false
}

const style = computed(() => {
  const dim = props.size === 'fill' ? '100%' : `${props.size / 10}rem`
  const h = props.hue
  return {
    width: dim,
    height: props.size === 'fill' ? 'auto' : dim,
    aspectRatio: props.size === 'fill' ? '1' : undefined,
    borderRadius: `${props.radius / 10}rem`,
    // Generated art for songs/playlists without an image: two-tone gradient + soft light source.
    background: shown.value
      ? '#1d1a21'
      : `radial-gradient(circle at 78% 18%, hsla(${(h + 30) % 360}, 90%, 70%, 0.55), transparent 55%),
         radial-gradient(circle at 12% 95%, hsla(${(h + 320) % 360}, 80%, 45%, 0.6), transparent 60%),
         linear-gradient(150deg, hsl(${h}, 62%, 40%), hsl(${(h + 40) % 360}, 55%, 16%))`,
  }
})

const iconSize = computed(() => (props.size === 'fill' ? 56 : Math.max(12, props.size * 0.38)))
</script>

<template>
  <div class="cover" :style="style">
    <img v-if="shown" :src="shown" alt="" loading="lazy" @load="onLoad" @error="onError" />
    <Icon v-else :name="icon" :size="iconSize" />
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
  color: rgba(255, 255, 255, 0.78);
}

.cover::after {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  box-shadow: inset 0 0 0 0.1rem rgba(255, 255, 255, 0.08);
  pointer-events: none;
}

.cover img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
