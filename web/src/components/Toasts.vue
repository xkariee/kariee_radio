<script setup lang="ts">
import { store } from '../store'
import Icon from './Icon.vue'
</script>

<template>
  <div class="toasts" role="status" aria-live="polite" aria-atomic="false">
    <TransitionGroup name="toast">
      <div v-for="t in store.state.toasts" :key="t.id" class="toast" :class="t.tone">
        <span class="t-icon"><Icon :name="t.icon" :size="15" :filled="t.tone === 'like'" /></span>
        <span class="t-text">{{ t.text }}</span>
        <button class="t-x" aria-label="Dismiss" @click="store.dismissToast(t.id)">
          <Icon name="x" :size="13" />
        </button>
      </div>
    </TransitionGroup>
  </div>
</template>

<style scoped>
.toasts {
  position: absolute;
  left: 50%;
  bottom: 11.4rem;
  z-index: 100;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column-reverse;
  align-items: center;
  gap: 0.8rem;
  pointer-events: none;
}

.toast {
  display: flex;
  align-items: center;
  gap: 1rem;
  max-width: 48rem;
  padding: 0.7rem 0.7rem 0.7rem 0.8rem;
  border-radius: var(--r-pill);
  background: var(--text-h);
  color: #17141b;
  font-size: 1.3rem;
  font-weight: 650;
  box-shadow: 0 1.2rem 3.2rem -0.8rem rgba(0, 0, 0, 0.7);
  pointer-events: auto;
}

.t-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.6rem;
  height: 2.6rem;
  border-radius: 50%;
  background: var(--accent);
  color: var(--on-accent);
  flex-shrink: 0;
}

.toast.like .t-icon {
  background: var(--like);
  color: #fff;
}

.toast.danger .t-icon {
  background: #e5484d;
  color: #fff;
}

.t-text {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.t-x {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.4rem;
  height: 2.4rem;
  border-radius: 50%;
  color: #5d5764;
  flex-shrink: 0;
}

.t-x:hover {
  background: rgba(0, 0, 0, 0.08);
  color: #17141b;
}

.toast-enter-active {
  transition:
    opacity 0.25s var(--ease),
    transform 0.35s var(--ease-spring);
}

.toast-leave-active {
  transition:
    opacity 0.2s var(--ease),
    transform 0.2s var(--ease);
}

.toast-enter-from {
  opacity: 0;
  transform: translateY(1.2rem) scale(0.9);
}

.toast-leave-to {
  opacity: 0;
  transform: scale(0.94);
}
</style>
