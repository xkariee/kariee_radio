<script setup lang="ts">
import Icon from './Icon.vue'

defineProps<{ label: string; description?: string; icon?: string }>()
const model = defineModel<boolean>({ required: true })
</script>

<template>
  <button type="button" class="toggle-row" role="switch" :aria-checked="model" @click="model = !model">
    <span v-if="icon" class="t-icon" aria-hidden="true"><Icon :name="icon" :size="17" /></span>
    <span class="t-text">
      <span class="t-label">{{ label }}</span>
      <span v-if="description" class="t-desc">{{ description }}</span>
    </span>
    <span class="track" aria-hidden="true"><span class="thumb" /></span>
  </button>
</template>

<style scoped>
.toggle-row {
  display: flex;
  align-items: center;
  gap: 1.2rem;
  width: 100%;
  padding: 1rem 1.2rem;
  border-radius: var(--r-md);
  text-align: left;
  transition: background-color 0.15s var(--ease);
}

.toggle-row:hover {
  background: var(--fill-2);
}

.t-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3.4rem;
  height: 3.4rem;
  border-radius: 1rem;
  background: var(--fill-2);
  color: var(--text-dim);
  flex-shrink: 0;
}

.t-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.t-label {
  font-size: 1.4rem;
  font-weight: 650;
  color: var(--text-h);
}

.t-desc {
  font-size: 1.2rem;
  color: var(--text-dim);
}

.track {
  position: relative;
  width: 4.4rem;
  height: 2.6rem;
  flex-shrink: 0;
  border-radius: var(--r-pill);
  background: var(--fill-4);
  transition: background-color 0.2s var(--ease);
}

.thumb {
  position: absolute;
  top: 0.3rem;
  left: 0.3rem;
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 0.2rem 0.6rem rgba(0, 0, 0, 0.35);
  transition: transform 0.22s var(--ease-spring);
}

.toggle-row[aria-checked='true'] .track {
  background: var(--accent);
}

.toggle-row[aria-checked='true'] .thumb {
  transform: translateX(1.8rem);
}
</style>
