<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, ref, useId } from 'vue'
import Icon from './Icon.vue'

defineProps<{ title: string; subtitle?: string; width?: number; icon?: string; tone?: 'danger' }>()
const emit = defineEmits<{ close: [] }>()

const dialog = ref<HTMLElement | null>(null)
const titleId = useId()
let returnFocus: HTMLElement | null = null

const focusables = () =>
  Array.from(
    dialog.value?.querySelectorAll<HTMLElement>(
      'button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea, [tabindex]:not([tabindex="-1"])',
    ) ?? [],
  ).filter((el) => el.offsetParent !== null)

// Escape is handled centrally (App.vue peels layers in order); this only keeps Tab inside.
function onKey(e: KeyboardEvent) {
  if (e.key !== 'Tab') return
  const list = focusables()
  if (!list.length) return
  const first = list[0]
  const last = list[list.length - 1]
  if (e.shiftKey && document.activeElement === first) {
    e.preventDefault()
    last.focus()
  } else if (!e.shiftKey && document.activeElement === last) {
    e.preventDefault()
    first.focus()
  }
}

onMounted(async () => {
  returnFocus = document.activeElement as HTMLElement | null
  await nextTick()
  const preferred = dialog.value?.querySelector<HTMLElement>('[autofocus], input:not([type="range"])')
  ;(preferred ?? focusables()[1] ?? focusables()[0])?.focus()
})

onUnmounted(() => {
  if (returnFocus && document.contains(returnFocus)) returnFocus.focus({ preventScroll: true })
})

</script>

<template>
  <Teleport to="body">
    <Transition name="modal" appear>
      <div class="overlay" @mousedown.self="emit('close')">
        <div
          ref="dialog"
          class="modal"
          role="dialog"
          aria-modal="true"
          :aria-labelledby="titleId"
          :style="{ width: (width ?? 420) / 10 + 'rem' }"
          @keydown="onKey"
        >
          <header class="modal-head">
            <span v-if="icon" class="head-icon" :class="tone" aria-hidden="true"><Icon :name="icon" :size="18" /></span>
            <div class="head-text">
              <h2 :id="titleId">{{ title }}</h2>
              <p v-if="subtitle">{{ subtitle }}</p>
            </div>
            <button class="icon-btn sm" aria-label="Close dialog" @click="emit('close')">
              <Icon name="x" :size="17" />
            </button>
          </header>
          <div class="modal-body">
            <slot />
          </div>
          <footer v-if="$slots.footer" class="modal-foot">
            <slot name="footer" />
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.overlay {
  position: fixed;
  inset: 0;
  z-index: 300;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.6rem;
  background: rgba(6, 5, 8, 0.45);
}

.modal {
  max-width: 100%;
  max-height: calc(100vh - 3.2rem);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border-radius: var(--r-xl);
  background: var(--panel-raised);
  border: 0.1rem solid var(--line-2);
  box-shadow: var(--shadow-pop), var(--highlight);
}

.modal-head {
  display: flex;
  align-items: flex-start;
  gap: 1.2rem;
  padding: 2rem 1.6rem 0.4rem 2.2rem;
}

.head-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3.6rem;
  height: 3.6rem;
  border-radius: 1.1rem;
  background: var(--accent-soft);
  color: var(--accent);
  flex-shrink: 0;
}

.head-icon.danger {
  background: var(--danger-soft);
  color: var(--danger);
}

.head-text {
  flex: 1;
  min-width: 0;
  padding-top: 0.2rem;
}

.modal-head h2 {
  font-size: 1.85rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: var(--text-h);
  overflow-wrap: anywhere;
}

.modal-head p {
  margin-top: 0.2rem;
  font-size: 1.3rem;
  color: var(--text-dim);
}

.modal-body {
  padding: 1.6rem 2.2rem 2.2rem;
  overflow-y: auto;
}

.modal-foot {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.8rem;
  padding: 1.4rem 2.2rem;
  border-top: 0.1rem solid var(--line);
  background: var(--fill-1);
}

.modal-enter-active {
  transition: opacity 0.2s var(--ease);
}

.modal-enter-active .modal {
  transition:
    opacity 0.2s var(--ease),
    transform 0.28s var(--ease-out);
}

.modal-enter-from {
  opacity: 0;
}

.modal-enter-from .modal {
  opacity: 0;
  transform: scale(0.96) translateY(1rem);
}
</style>
