<script setup lang="ts">
import { computed, nextTick, onUnmounted, ref, watch } from 'vue'
import { store } from '../store'
import Icon from './Icon.vue'

const { state } = store

const btn = ref<HTMLElement | null>(null)
const menu = ref<HTMLElement | null>(null)
const tapBtn = ref<HTMLElement | null>(null)

const open = computed(() => state.popover === 'lights')
const tapsLeft = computed(() => Math.max(0, 4 - state.tapCount))

const status = computed(() => {
  if (state.tapCount > 0 && tapsLeft.value > 0) return `Keep tapping… ${tapsLeft.value} more`
  if (state.tempo) return 'Locked to this song for everyone at the booth'
  return 'Not set yet. Lights run at a default tempo from the start of the song'
})

function toggle() {
  state.popover = open.value ? null : 'lights'
}

watch(open, async (o) => {
  if (o) {
    await nextTick()
    tapBtn.value?.focus()
    document.addEventListener('mousedown', onOutside)
  } else {
    document.removeEventListener('mousedown', onOutside)
  }
})

function onOutside(e: MouseEvent) {
  const t = e.target as Node
  if (!menu.value?.contains(t) && !btn.value?.contains(t)) state.popover = null
}

function onTapKey(e: KeyboardEvent) {
  if (!e.repeat) store.tapTempo()
}

function onMenuKey(e: KeyboardEvent) {
  if (e.key === 'Escape') {
    e.preventDefault()
    e.stopPropagation()
    state.popover = null
    btn.value?.focus()
  }
}

onUnmounted(() => document.removeEventListener('mousedown', onOutside))
</script>

<template>
  <div class="lights-wrap">
    <button
      ref="btn"
      class="icon-btn"
      :class="{ on: !!state.tempo }"
      aria-haspopup="dialog"
      :aria-expanded="open"
      :aria-label="state.tempo ? `Light sync, ${state.tempo.bpm} BPM` : 'Light sync'"
      title="Sync the disco lights to the beat"
      @click="toggle"
    >
      <Icon name="sparkles" :size="18" />
      <span v-if="state.tempo" class="badge" aria-hidden="true">{{ state.tempo.bpm }}</span>
    </button>
    <Transition name="pop">
      <div v-if="open" ref="menu" class="popover" role="dialog" aria-label="Light sync" @keydown="onMenuKey">
        <p class="pop-title">Light sync</p>

        <div class="readout">
          <button class="icon-btn sm" aria-label="1 BPM slower" :disabled="!state.tempo" @click="store.nudgeTempo(-1)">
            <Icon name="minus" :size="16" />
          </button>
          <p class="bpm" aria-live="polite">
            <span class="bpm-num">{{ state.tempo ? state.tempo.bpm : '—' }}</span>
            <span class="bpm-unit">BPM</span>
          </p>
          <button class="icon-btn sm" aria-label="1 BPM faster" :disabled="!state.tempo" @click="store.nudgeTempo(1)">
            <Icon name="plus" :size="16" />
          </button>
        </div>
        <p class="status">{{ status }}</p>

        <!-- Taps on press, not release, so the timing is what you felt. Alternating the animation
             name restarts the flash on every tap without re-creating (and unfocusing) the button. -->
        <button
          ref="tapBtn"
          class="btn btn-primary tap"
          :class="state.tapCount ? (state.tapCount % 2 ? 'hit-a' : 'hit-b') : ''"
          :disabled="!state.isPlaying"
          @mousedown.prevent="store.tapTempo()"
          @keydown.space.prevent="onTapKey"
          @keydown.enter.prevent="onTapKey"
        >
          Tap to the beat
          <kbd>T</kbd>
        </button>
        <p class="hint">
          Start on the first beat of a bar and tap at least 4 times. One tap later on just realigns the beat. It’s
          remembered for this song.
        </p>

        <button v-if="state.tempo" class="btn btn-quiet sm reset" @click="store.resetTempo()">
          <Icon name="rotate-ccw" :size="14" /> Reset to default
        </button>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.lights-wrap {
  position: relative;
}

.badge {
  position: absolute;
  top: -0.2rem;
  right: -0.8rem;
  min-width: 2rem;
  padding: 0.1rem 0.5rem;
  border-radius: var(--r-pill);
  background: var(--accent);
  color: var(--on-accent);
  font-size: 0.95rem;
  font-weight: 800;
  line-height: 1.5;
  font-variant-numeric: tabular-nums;
}

.popover {
  position: absolute;
  bottom: calc(100% + 1.4rem);
  right: -8rem;
  z-index: 50;
  width: 27rem;
  padding: 0.6rem 1.2rem 1.2rem;
  border-radius: var(--r-lg);
  background: var(--panel-raised);
  border: 0.1rem solid var(--line-2);
  box-shadow: var(--shadow-pop);
  transform-origin: bottom center;
}

.pop-title {
  padding: 0.8rem 0 0.4rem;
  font-size: 1.15rem;
  font-weight: 750;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--text-faint);
}

.readout {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.4rem 0;
}

.bpm {
  display: flex;
  align-items: baseline;
  gap: 0.6rem;
}

.bpm-num {
  font-size: 3.4rem;
  font-weight: 800;
  color: var(--text-h);
  font-variant-numeric: tabular-nums;
  line-height: 1;
}

.bpm-unit {
  font-size: 1.2rem;
  font-weight: 700;
  color: var(--text-faint);
}

.status {
  min-height: 3.4rem;
  font-size: 1.2rem;
  color: var(--text-dim);
  text-align: center;
}

.tap {
  width: 100%;
  height: 4.6rem;
  margin-top: 0.4rem;
  font-size: 1.45rem;
}

.tap kbd {
  padding: 0.1rem 0.6rem;
  border-radius: var(--r-xs);
  background: rgba(0, 0, 0, 0.18);
  font-family: inherit;
  font-size: 1.1rem;
  font-weight: 800;
}

.tap.hit-a {
  animation: tap-hit-a 0.22s var(--ease);
}

.tap.hit-b {
  animation: tap-hit-b 0.22s var(--ease);
}

@keyframes tap-hit-a {
  from {
    transform: scale(0.95);
    box-shadow: 0 0 0 0.6rem var(--accent-glow);
  }
}

@keyframes tap-hit-b {
  from {
    transform: scale(0.95);
    box-shadow: 0 0 0 0.6rem var(--accent-glow);
  }
}

.hint {
  margin-top: 0.9rem;
  font-size: 1.15rem;
  line-height: 1.45;
  color: var(--text-faint);
}

.reset {
  margin-top: 0.6rem;
  padding: 0 0.8rem;
}
</style>
