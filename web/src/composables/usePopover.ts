import { computed, nextTick, onUnmounted, watch, type Ref } from 'vue'
import { state, type Popover } from '../store/state'

export function usePopover(
  name: NonNullable<Popover>,
  trigger: Ref<HTMLElement | null>,
  panel: Ref<HTMLElement | null>,
  focusOnOpen: () => HTMLElement | null | undefined,
) {
  const open = computed(() => state.popover === name)

  function onOutside(e: MouseEvent) {
    const target = e.target as Node
    if (!panel.value?.contains(target) && !trigger.value?.contains(target)) state.popover = null
  }

  function toggle() {
    state.popover = open.value ? null : name
  }

  function close() {
    state.popover = null
    trigger.value?.focus()
  }

  watch(open, async (isOpen) => {
    if (!isOpen) return document.removeEventListener('mousedown', onOutside)
    await nextTick()
    focusOnOpen()?.focus()
    document.addEventListener('mousedown', onOutside)
  })

  onUnmounted(() => document.removeEventListener('mousedown', onOutside))

  return { open, toggle, close }
}
