<script setup lang="ts">
import Icon from './Icon.vue'

defineProps<{ title: string; width?: number }>()
const emit = defineEmits<{ close: [] }>()
</script>

<template>
  <Transition name="modal" appear>
    <div class="overlay" @mousedown.self="emit('close')">
      <div class="modal" :style="{ width: (width ?? 380) + 'px' }">
        <div class="modal-head">
          <h2>{{ title }}</h2>
          <button class="btn-icon ghost" @click="emit('close')">
            <Icon name="x" :size="16" />
          </button>
        </div>
        <div class="modal-body">
          <slot />
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.overlay {
  position: fixed;
  inset: 0;
  background: rgba(6, 8, 11, 0.65);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 300;
}

.modal {
  background: var(--surface-2);
  border: 1px solid var(--line);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
  max-width: calc(100vw - 32px);
  max-height: calc(100vh - 32px);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.modal-enter-active {
  transition: opacity 0.18s var(--ease);
}

.modal-enter-active .modal {
  transition:
    opacity 0.18s var(--ease),
    transform 0.18s var(--ease);
}

.modal-enter-from {
  opacity: 0;
}

.modal-enter-from .modal {
  opacity: 0;
  transform: scale(0.95) translateY(6px);
}

.modal-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 16px;
  border-bottom: 1px solid var(--line);
  flex-shrink: 0;
}

.modal-head h2 {
  font-size: 14.5px;
  font-weight: 600;
  color: var(--text-h);
  margin: 0;
}

.modal-body {
  padding: 16px;
  overflow-y: auto;
}
</style>
