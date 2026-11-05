<script setup lang="ts" generic="T extends string">
import { computed, nextTick, onUnmounted, ref, useId, watch } from 'vue'
import Icon from './Icon.vue'

// Styled stand-in for <select>: the native popup can't be themed in CEF and looked out of place.
// Follows the listbox pattern - arrows/Home/End move, Enter/Space pick, Esc/Tab close.
const props = withDefaults(
  defineProps<{
    options: { value: T; label: string }[]
    label: string
    icon?: string
    align?: 'start' | 'end'
  }>(),
  { icon: undefined, align: 'start' },
)
const model = defineModel<T>({ required: true })

const id = useId()
const open = ref(false)
const active = ref(0)
const trigger = ref<HTMLElement | null>(null)
const list = ref<HTMLElement | null>(null)
const pos = ref({ left: 0, top: 0, minWidth: 0 })
const placeAbove = ref(false)

const current = computed(() => props.options.find((o) => o.value === model.value) ?? props.options[0])

async function show() {
  active.value = Math.max(
    0,
    props.options.findIndex((o) => o.value === model.value),
  )
  open.value = true
  await nextTick()
  place()
  list.value?.focus({ preventScroll: true })
}

function hide(refocus = true) {
  open.value = false
  if (refocus) trigger.value?.focus({ preventScroll: true })
}

// Fixed + teleported, so the scrolling content area can't clip it; flips up near the bottom.
function place() {
  const t = trigger.value?.getBoundingClientRect()
  const l = list.value
  if (!t || !l) return
  const w = Math.max(l.offsetWidth, t.width)
  const h = l.offsetHeight
  placeAbove.value = t.bottom + 6 + h > window.innerHeight - 8
  pos.value = {
    left: Math.max(8, Math.min(props.align === 'end' ? t.right - w : t.left, window.innerWidth - w - 8)),
    top: placeAbove.value ? t.top - 6 - h : t.bottom + 6,
    minWidth: t.width,
  }
}

function choose(i: number) {
  model.value = props.options[i].value
  hide()
}

function onTriggerKey(e: KeyboardEvent) {
  if (['ArrowDown', 'ArrowUp', 'Enter', ' '].includes(e.key)) {
    e.preventDefault()
    e.stopPropagation()
    show()
  }
}

function onListKey(e: KeyboardEvent) {
  const last = props.options.length - 1
  const keys: Record<string, () => void> = {
    ArrowDown: () => (active.value = Math.min(last, active.value + 1)),
    ArrowUp: () => (active.value = Math.max(0, active.value - 1)),
    Home: () => (active.value = 0),
    End: () => (active.value = last),
    Enter: () => choose(active.value),
    ' ': () => choose(active.value),
    Escape: () => hide(),
    Tab: () => hide(),
  }
  if (!keys[e.key]) return
  e.preventDefault()
  e.stopPropagation()
  keys[e.key]()
}

function onOutside(e: Event) {
  const t = e.target as Node
  if (list.value?.contains(t) || trigger.value?.contains(t)) return
  hide(false)
}

watch(open, (isOpen) => {
  const method = isOpen ? 'addEventListener' : 'removeEventListener'
  document[method]('mousedown', onOutside)
  document[method]('scroll', onOutside, true)
  window[method]('resize', onOutside)
})

onUnmounted(() => {
  document.removeEventListener('mousedown', onOutside)
  document.removeEventListener('scroll', onOutside, true)
  window.removeEventListener('resize', onOutside)
})
</script>

<template>
  <button
    ref="trigger"
    type="button"
    class="dd-trigger"
    :class="{ open }"
    aria-haspopup="listbox"
    :aria-expanded="open"
    :aria-controls="`${id}-list`"
    :aria-label="`${label}: ${current?.label}`"
    @click="open ? hide() : show()"
    @keydown="onTriggerKey"
  >
    <Icon v-if="icon" :name="icon" :size="14" class="dd-icon" />
    <span class="dd-value">{{ current?.label }}</span>
    <Icon name="chevron-down" :size="14" class="dd-chevron" />
  </button>

  <Teleport to="body">
    <Transition name="dd">
      <ul
        v-if="open"
        :id="`${id}-list`"
        ref="list"
        class="dd-list"
        :class="{ above: placeAbove, end: align === 'end' }"
        role="listbox"
        tabindex="-1"
        :aria-label="label"
        :aria-activedescendant="`${id}-opt-${active}`"
        :style="{ left: pos.left + 'px', top: pos.top + 'px', minWidth: pos.minWidth + 'px' }"
        @keydown="onListKey"
      >
        <li class="dd-label" aria-hidden="true">{{ label }}</li>
        <li
          v-for="(o, i) in options"
          :id="`${id}-opt-${i}`"
          :key="o.value"
          class="dd-option"
          :class="{ active: i === active, selected: o.value === model }"
          role="option"
          :aria-selected="o.value === model"
          @mousemove="active = i"
          @click="choose(i)"
        >
          <span>{{ o.label }}</span>
          <Icon v-if="o.value === model" name="check" :size="15" />
        </li>
      </ul>
    </Transition>
  </Teleport>
</template>

<style scoped>
.dd-trigger {
  display: inline-flex;
  align-items: center;
  gap: 0.8rem;
  height: 3.4rem;
  padding: 0 1.1rem 0 1.3rem;
  border-radius: var(--r-pill);
  background: var(--fill-2);
  border: 0.1rem solid var(--line);
  color: var(--text-h);
  font-size: 1.25rem;
  font-weight: 650;
  white-space: nowrap;
  transition:
    background-color 0.16s var(--ease),
    border-color 0.16s var(--ease);
}

.dd-trigger:hover,
.dd-trigger.open {
  background: var(--fill-3);
}

.dd-trigger.open {
  border-color: var(--accent-line);
}

.dd-icon {
  color: var(--text-dim);
}

.dd-chevron {
  color: var(--text-dim);
  transition: transform 0.22s var(--ease-out);
}

.dd-trigger.open .dd-chevron {
  transform: rotate(180deg);
}

.dd-list {
  position: fixed;
  z-index: 350; /* above modals (300) - also used inside them */
  margin: 0;
  padding: 0.6rem;
  list-style: none;
  min-width: 18rem;
  border-radius: var(--r-lg);
  background: var(--panel-raised);
  border: 0.1rem solid var(--line-2);
  box-shadow: var(--shadow-pop);
  font-family: var(--font);
  transform-origin: top left;
  outline: none;
}

.dd-list.end {
  transform-origin: top right;
}

.dd-list.above {
  transform-origin: bottom left;
}

.dd-list.above.end {
  transform-origin: bottom right;
}

.dd-list:focus-visible {
  box-shadow:
    var(--shadow-pop),
    0 0 0 0.2rem var(--accent-line);
}

.dd-label {
  padding: 0.7rem 1rem 0.5rem;
  font-size: 1.05rem;
  font-weight: 750;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-faint);
}

.dd-option {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1.6rem;
  height: 3.6rem;
  padding: 0 1rem;
  border-radius: var(--r-sm);
  font-size: 1.35rem;
  font-weight: 600;
  color: var(--text);
  cursor: pointer;
}

.dd-option.active {
  background: var(--fill-3);
  color: var(--text-h);
}

.dd-option.selected {
  color: var(--accent);
}

.dd-enter-active {
  transition:
    opacity 0.16s var(--ease),
    transform 0.22s var(--ease-out);
}

.dd-leave-active {
  transition:
    opacity 0.1s var(--ease),
    transform 0.1s var(--ease);
}

.dd-enter-from,
.dd-leave-to {
  opacity: 0;
  transform: scale(0.96) translateY(-0.4rem);
}

.dd-list.above.dd-enter-from,
.dd-list.above.dd-leave-to {
  transform: scale(0.96) translateY(0.4rem);
}
</style>
