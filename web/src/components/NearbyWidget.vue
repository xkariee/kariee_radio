<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import type { LiveBroadcast } from '../types'
import { store } from '../store'
import { WIDGET_DEFAULT_POS, paletteFor, settings } from '../settings'
import Icon from './Icon.vue'
import Cover from './Cover.vue'

// Small "now playing nearby" card: shows while you're in range of a DJ booth (or inside its
// room) with the radio panel closed. In move mode it can be dragged anywhere on screen.
const { state } = store

// Shown while moving the widget when nothing happens to be in range.
const preview: LiveBroadcast = {
  id: 'preview',
  kind: 'dj',
  label: 'DJ booth preview',
  song: { id: 'preview', title: 'Song from the nearby booth', artist: 'Artist name', duration: 214, hue: 280, videoId: '' },
  playing: true,
  progress: 72,
  syncedAt: Date.now(),
}

const editing = computed(() => state.widgetEditing)
const b = computed(() => store.widgetBroadcast.value ?? (editing.value ? preview : null))
const visible = computed(
  () =>
    state.widgetServerEnabled &&
    !!b.value &&
    !state.creator &&
    (editing.value || (settings.widget && !state.visible)),
)
const compact = computed(() => settings.widgetSize === 'compact')

const progress = computed(() => (!b.value ? 0 : b.value.id === 'preview' ? b.value.progress : store.liveProgress(b.value)))
const duration = computed(() => b.value?.song.duration ?? 0)
const pct = computed(() => `${duration.value ? Math.min(100, (progress.value / duration.value) * 100) : 0}%`)
const palette = computed(() => paletteFor(b.value?.song.hue ?? 330))

const kicker = computed(() => {
  if (!b.value) return ''
  if (b.value.kind === 'dj') return b.value.label
  return b.value.kind === 'radiocar' ? 'Car radio nearby' : 'Radio nearby'
})

const position = computed(() => ({
  left: `${settings.widgetX * 100}%`,
  top: `${settings.widgetY * 100}%`,
  transform: `translate(${-settings.widgetX * 100}%, ${-settings.widgetY * 100}%)`,
}))

// ─── move mode ───
const layer = ref<HTMLElement | null>(null)
const card = ref<HTMLElement | null>(null)
const dragging = ref(false)
let grab = { dx: 0, dy: 0 }

const clamp = (v: number) => Math.min(1, Math.max(0, v))
// Sticks to the edges and the centre line so it's easy to line up.
const snap = (v: number) => (v < 0.015 ? 0 : v > 0.985 ? 1 : Math.abs(v - 0.5) < 0.015 ? 0.5 : v)

function onDown(e: PointerEvent) {
  if (!editing.value || !card.value) return
  e.preventDefault()
  const r = card.value.getBoundingClientRect()
  grab = { dx: e.clientX - r.left, dy: e.clientY - r.top }
  card.value.setPointerCapture(e.pointerId)
  card.value.focus({ preventScroll: true })
  dragging.value = true
}

function onMove(e: PointerEvent) {
  if (!dragging.value || !layer.value || !card.value) return
  const area = layer.value.getBoundingClientRect()
  const r = card.value.getBoundingClientRect()
  const freeW = area.width - r.width
  const freeH = area.height - r.height
  settings.widgetX = snap(clamp(freeW > 0 ? (e.clientX - grab.dx - area.left) / freeW : 0))
  settings.widgetY = snap(clamp(freeH > 0 ? (e.clientY - grab.dy - area.top) / freeH : 0))
}

function onUp() {
  dragging.value = false
}

function onKey(e: KeyboardEvent) {
  if (!editing.value) return
  const step = e.shiftKey ? 0.05 : 0.01
  const moves: Record<string, () => void> = {
    ArrowLeft: () => (settings.widgetX = clamp(settings.widgetX - step)),
    ArrowRight: () => (settings.widgetX = clamp(settings.widgetX + step)),
    ArrowUp: () => (settings.widgetY = clamp(settings.widgetY - step)),
    ArrowDown: () => (settings.widgetY = clamp(settings.widgetY + step)),
    Enter: () => store.finishWidgetEditing(),
  }
  if (!moves[e.key]) return
  e.preventDefault()
  e.stopPropagation()
  moves[e.key]()
}

function place(x: number, y: number) {
  settings.widgetX = x
  settings.widgetY = y
}

function reset() {
  place(WIDGET_DEFAULT_POS.x, WIDGET_DEFAULT_POS.y)
}

watch(editing, async (on) => {
  if (!on) return
  await nextTick()
  card.value?.focus({ preventScroll: true })
})

const corners = [
  { x: 0, y: 0, icon: 'arrow-up', rot: -45, label: 'Top left' },
  { x: 0.5, y: 0, icon: 'arrow-up', rot: 0, label: 'Top centre' },
  { x: 1, y: 0, icon: 'arrow-up', rot: 45, label: 'Top right' },
  { x: 0, y: 1, icon: 'arrow-down', rot: 45, label: 'Bottom left' },
  { x: 0.5, y: 1, icon: 'arrow-down', rot: 0, label: 'Bottom centre' },
  { x: 1, y: 1, icon: 'arrow-down', rot: -45, label: 'Bottom right' },
]
</script>

<template>
  <Transition name="scrim">
    <div v-if="editing" class="scrim" aria-hidden="true">
      <span class="guide v" />
      <span class="guide h" />
    </div>
  </Transition>

  <Transition name="bar">
    <div v-if="editing" class="edit-bar" role="toolbar" aria-label="Move the now playing widget">
      <span class="edit-icon" aria-hidden="true"><Icon name="move" :size="16" /></span>
      <span class="edit-text">
        <b>Drag the widget anywhere</b>
        <span>Arrow keys nudge it · it snaps to edges and the centre</span>
      </span>
      <span class="edit-corners" role="group" aria-label="Quick positions">
        <button
          v-for="c in corners"
          :key="c.label"
          class="icon-btn sm"
          :aria-label="`Move to ${c.label.toLowerCase()}`"
          :title="c.label"
          @click="place(c.x, c.y)"
        >
          <Icon :name="c.icon" :size="14" :style="{ transform: `rotate(${c.rot}deg)` }" />
        </button>
      </span>
      <button class="btn btn-quiet sm" @click="reset"><Icon name="rotate-ccw" :size="13" /> Reset</button>
      <button class="btn btn-primary sm" @click="store.finishWidgetEditing()">Done</button>
    </div>
  </Transition>

  <div ref="layer" class="layer">
    <Transition name="widget">
      <div
        v-if="visible && b"
        ref="card"
        class="widget"
        :class="{ compact, editing, dragging, paused: !b.playing }"
        :style="{ ...position, '--wa': palette['--accent'], '--was': palette['--accent-glow'] }"
        :tabindex="editing ? 0 : -1"
        :role="editing ? 'application' : 'status'"
        :aria-label="
          editing
            ? 'Now playing widget. Drag it, or use the arrow keys to move it. Press Enter when done.'
            : `Now playing nearby: ${b.song.title} by ${b.song.artist}`
        "
        @pointerdown="onDown"
        @pointermove="onMove"
        @pointerup="onUp"
        @pointercancel="onUp"
        @keydown="onKey"
      >
        <span class="glow" aria-hidden="true" />
        <Transition name="swap" mode="out-in">
          <div :key="b.song.id" class="inner">
            <div class="art">
              <Cover :src="b.song.thumbnail ?? null" :hue="b.song.hue" :size="compact ? 42 : 60" :radius="compact ? 9 : 12" />
              <span v-if="!compact && b.playing" class="art-eq" aria-hidden="true">
                <span class="eq live"><i /><i /><i /></span>
              </span>
            </div>
            <div class="meta">
              <span v-if="!compact" class="kicker">
                <span class="dot" :class="{ live: b.playing }" aria-hidden="true" />
                <span class="kicker-text truncate">{{ b.playing ? kicker : `Paused · ${kicker}` }}</span>
              </span>
              <span class="title truncate">{{ b.song.title }}</span>
              <span class="artist truncate">{{ b.song.artist }}</span>
              <template v-if="!compact">
                <span class="bar"><span :style="{ width: pct }" /></span>
                <span class="times">
                  <span>{{ store.formatTime(progress) }}</span>
                  <span>{{ store.formatTime(duration) }}</span>
                </span>
              </template>
            </div>
            <span v-if="compact" class="eq" :class="{ live: b.playing }" aria-hidden="true"><i /><i /><i /></span>
          </div>
        </Transition>
        <span v-if="compact" class="bar thin" aria-hidden="true"><span :style="{ width: pct }" /></span>
        <span v-if="editing" class="handle" aria-hidden="true"><Icon name="move" :size="14" /></span>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.layer {
  position: fixed;
  inset: 2.4rem;
  z-index: 150;
  pointer-events: none;
}

.widget {
  position: absolute;
  width: 34rem;
  padding: 1.2rem;
  border-radius: 1.8rem;
  background: rgba(18, 16, 22, 0.9);
  border: 0.1rem solid rgba(255, 255, 255, 0.1);
  box-shadow:
    0 1.6rem 4rem -1.2rem rgba(0, 0, 0, 0.7),
    inset 0 0.1rem 0 rgba(255, 255, 255, 0.06);
  overflow: hidden;
  color: var(--text);
  font-family: var(--font);
  pointer-events: none;
}

.widget.compact {
  width: 27rem;
  padding: 0.8rem 1.2rem 0.8rem 0.8rem;
  border-radius: 1.4rem;
}

.widget.editing {
  pointer-events: auto;
  cursor: grab;
  outline: 0.2rem dashed rgba(255, 255, 255, 0.55);
  outline-offset: 0.5rem;
}

.widget.editing:focus-visible {
  outline: 0.2rem solid var(--accent);
}

.widget.dragging {
  cursor: grabbing;
  box-shadow:
    0 2.4rem 6rem -1rem rgba(0, 0, 0, 0.8),
    inset 0 0.1rem 0 rgba(255, 255, 255, 0.06);
}

/* tinted by the song's own colour, like the radio's adaptive accent */
.glow {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(22rem 10rem at 0% 0%, var(--wa), transparent 70%);
  opacity: 0.22;
  pointer-events: none;
  transition: background 0.6s var(--ease);
}

.inner {
  position: relative;
  display: flex;
  align-items: center;
  gap: 1.2rem;
}

.art {
  position: relative;
  flex-shrink: 0;
  border-radius: 1.2rem;
  box-shadow: 0 0.8rem 2rem -0.8rem rgba(0, 0, 0, 0.7);
}

.art-eq {
  position: absolute;
  right: -0.4rem;
  bottom: -0.4rem;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.4rem;
  height: 2.4rem;
  border-radius: 50%;
  background: rgba(18, 16, 22, 0.95);
  box-shadow: 0 0 0 0.2rem rgba(18, 16, 22, 0.95);
}

.art-eq .eq {
  height: 1rem;
  color: var(--wa);
}

.meta {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.kicker {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  margin-bottom: 0.2rem;
  font-size: 1.05rem;
  font-weight: 750;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--text-dim);
}

.dot {
  width: 0.7rem;
  height: 0.7rem;
  flex-shrink: 0;
  border-radius: 50%;
  background: var(--text-faint);
}

.dot.live {
  background: var(--wa);
  box-shadow: 0 0 0 0.3rem var(--was);
  animation: pulse 1.8s ease-in-out infinite;
}

@keyframes pulse {
  50% {
    box-shadow: 0 0 0 0.5rem transparent;
  }
}

.title {
  font-size: 1.5rem;
  font-weight: 750;
  color: var(--text-h);
  line-height: 1.3;
}

.artist {
  font-size: 1.25rem;
  color: var(--text-dim);
}

.compact .title {
  font-size: 1.35rem;
}

.compact .artist {
  font-size: 1.15rem;
}

.bar {
  display: block;
  height: 0.4rem;
  margin-top: 0.8rem;
  border-radius: var(--r-pill);
  background: rgba(255, 255, 255, 0.12);
  overflow: hidden;
}

.bar > span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--wa);
  transition: width 1s linear;
}

.bar.thin {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 0.3rem;
  margin: 0;
  border-radius: 0;
}

.times {
  display: flex;
  justify-content: space-between;
  margin-top: 0.4rem;
  font-size: 1.05rem;
  font-weight: 600;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
}

.compact .eq {
  color: var(--wa);
  margin-right: 0.4rem;
}

.paused .eq,
.paused .title {
  opacity: 0.75;
}

.handle {
  position: absolute;
  top: 0.6rem;
  right: 0.6rem;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.4rem;
  height: 2.4rem;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.12);
  color: #fff;
}

/* ─── move mode chrome ─── */

.scrim {
  position: fixed;
  inset: 0;
  z-index: 140;
  background: rgba(6, 5, 8, 0.35);
}

.guide {
  position: absolute;
  background: rgba(255, 255, 255, 0.12);
}

.guide.v {
  left: 50%;
  top: 0;
  bottom: 0;
  width: 0.1rem;
}

.guide.h {
  top: 50%;
  left: 0;
  right: 0;
  height: 0.1rem;
}

.edit-bar {
  position: fixed;
  top: 2.4rem;
  left: 50%;
  z-index: 160;
  transform: translateX(-50%);
  display: flex;
  align-items: center;
  gap: 1.2rem;
  padding: 0.8rem 0.8rem 0.8rem 1rem;
  border-radius: var(--r-pill);
  background: var(--panel-raised);
  border: 0.1rem solid var(--line-2);
  box-shadow: var(--shadow-pop);
  white-space: nowrap;
}

.edit-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3.6rem;
  height: 3.6rem;
  border-radius: 50%;
  background: var(--accent-soft);
  color: var(--accent);
}

.edit-text {
  display: flex;
  flex-direction: column;
  font-size: 1.2rem;
  color: var(--text-dim);
}

.edit-text b {
  font-size: 1.35rem;
  color: var(--text-h);
}

.edit-corners {
  display: flex;
  gap: 0.2rem;
  padding: 0 0.8rem;
  border-left: 0.1rem solid var(--line);
  border-right: 0.1rem solid var(--line);
}

/* ─── transitions ─── */

.widget-enter-active {
  transition:
    opacity 0.35s var(--ease),
    margin 0.45s var(--ease-out);
}

.widget-leave-active {
  transition:
    opacity 0.25s var(--ease),
    margin 0.25s var(--ease);
}

.widget-enter-from,
.widget-leave-to {
  opacity: 0;
  margin-top: 1rem;
}

.swap-enter-active,
.swap-leave-active {
  transition: opacity 0.2s var(--ease);
}

.swap-enter-from,
.swap-leave-to {
  opacity: 0;
}

.scrim-enter-active,
.scrim-leave-active,
.bar-enter-active,
.bar-leave-active {
  transition: opacity 0.2s var(--ease);
}

.scrim-enter-from,
.scrim-leave-to,
.bar-enter-from,
.bar-leave-to {
  opacity: 0;
}
</style>
