<script setup lang="ts">
import { computed, ref } from 'vue'
import { store } from '../store'
import { settings } from '../settings'
import { formatTime } from '../utils/format'
import { usePopover } from '../composables/usePopover'
import Icon from './Icon.vue'
import Cover from './Cover.vue'
import LightSync from './LightSync.vue'

const { state } = store
const song = store.currentSong

const seeking = ref(false)
const seekValue = ref(0)

const duration = computed(() => song.value?.duration ?? 0)
const shownProgress = computed(() => (seeking.value ? seekValue.value : state.progress))
const pct = (v: number, max: number) => `${max > 0 ? Math.min(100, Math.max(0, (v / max) * 100)) : 0}%`

function onSeekInput(e: Event) {
  seeking.value = true
  seekValue.value = Number((e.target as HTMLInputElement).value)
}

function onSeekCommit(e: Event) {
  store.seek(Number((e.target as HTMLInputElement).value))
  seeking.value = false
}

const volume = computed(() => (state.muted ? 0 : state.volume))

function onVolumeInput(e: Event) {
  const el = e.target as HTMLInputElement
  store.setVolume(Number(el.value))
  el.value = String(volume.value)
}

const volumeIcon = computed(() => {
  if (volume.value === 0) return 'volume-x'
  if (volume.value < 50) return 'volume-1'
  return 'volume-2'
})

function onWheel(e: WheelEvent) {
  store.setVolume(state.volume + (e.deltaY < 0 ? 5 : -5))
}

const repeatLabel = computed(() => {
  if (store.shared.value) return 'Repeat is not available on shared radios'
  return { off: 'Repeat off', all: 'Repeat queue', one: 'Repeat this song' }[state.repeat]
})

const liked = computed(() => !!song.value && store.isFavorite(song.value.id))

const sleepBtn = ref<HTMLElement | null>(null)
const sleepMenu = ref<HTMLElement | null>(null)

const sleepOptions: { label: string; value: number | 'end' | null }[] = [
  { label: '15 minutes', value: 15 },
  { label: '30 minutes', value: 30 },
  { label: '45 minutes', value: 45 },
  { label: '1 hour', value: 60 },
  { label: '2 hours', value: 120 },
  { label: 'End of this song', value: 'end' },
  { label: 'Off', value: null },
]

const sleepActive = computed(() => state.sleepEndsAt != null || state.sleepEndOfTrack)
const sleepBadge = computed(() => {
  if (state.sleepEndOfTrack) return '1♪'
  const s = store.sleepRemaining.value
  return s == null ? null : `${Math.ceil(s / 60)}m`
})

function isSelected(v: number | 'end' | null) {
  if (v === null) return !sleepActive.value
  if (v === 'end') return state.sleepEndOfTrack
  return false
}

const sleepItems = () => Array.from(sleepMenu.value?.querySelectorAll<HTMLElement>('[role="menuitemradio"]') ?? [])
const { open: sleepOpen, toggle: toggleSleep, close: closeSleep } = usePopover('sleep', sleepBtn, sleepMenu, () => sleepItems()[0])

function onMenuKey(e: KeyboardEvent) {
  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
    const items = sleepItems()
    const i = items.indexOf(document.activeElement as HTMLElement)
    items[(i + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length]?.focus()
  } else if (e.key === 'Tab' || e.key === 'Escape') {
    closeSleep()
  } else {
    return
  }
  e.preventDefault()
  e.stopPropagation()
}
</script>

<template>
  <footer class="panel dock" aria-label="Player controls" style="overflow: visible">
    <div class="now">
      <button
        class="now-art"
        :aria-label="settings.nowPlayingPanel ? 'Hide now playing panel' : 'Show now playing panel'"
        :title="settings.nowPlayingPanel ? 'Hide now playing panel' : 'Show now playing panel'"
        @click="settings.nowPlayingPanel = !settings.nowPlayingPanel"
      >
        <Cover :src="song?.thumbnail ?? null" :hue="song?.hue ?? 330" :size="56" :radius="12" :icon="song ? 'music' : 'radio'" />
        <span class="now-art-hint"><Icon name="panel-right" :size="16" /></span>
      </button>
      <div class="now-meta" aria-live="polite">
        <template v-if="song">
          <span class="now-title truncate" :title="song.title">{{ song.title }}</span>
          <span class="now-artist truncate">{{ song.artist }}</span>
        </template>
        <template v-else>
          <span class="now-title muted">Nothing playing</span>
          <span class="now-artist">Pick something to get started</span>
        </template>
      </div>
      <button
        v-if="song"
        class="icon-btn"
        :class="{ liked }"
        :aria-label="liked ? 'Remove from Liked Songs' : 'Add to Liked Songs'"
        :title="liked ? 'Remove from Liked Songs (L)' : 'Add to Liked Songs (L)'"
        @click="store.toggleFavorite(song.id)"
      >
        <Icon name="heart" :size="19" :filled="liked" />
      </button>
    </div>

    <div class="center">
      <div class="transport">
        <button
          class="icon-btn"
          :aria-pressed="state.shuffle"
          :aria-label="state.shuffle ? 'Shuffle on' : 'Shuffle off'"
          :title="(state.shuffle ? 'Shuffle on' : 'Shuffle off') + ' (S)'"
          @click="store.toggleShuffle()"
        >
          <Icon name="shuffle" :size="18" />
        </button>
        <button class="icon-btn lg" aria-label="Previous" title="Previous (Shift+←)" :disabled="!song" @click="store.prev">
          <Icon name="skip-back" :size="21" />
        </button>
        <button
          class="play-fab main-play"
          :disabled="!song"
          :aria-label="state.isPlaying ? 'Pause' : 'Play'"
          :title="(state.isPlaying ? 'Pause' : 'Play') + ' (Space)'"
          @click="store.togglePlay"
        >
          <Icon :name="state.isPlaying ? 'pause' : 'play'" :size="22" />
        </button>
        <button class="icon-btn lg" aria-label="Next" title="Next (Shift+→)" :disabled="!song" @click="store.next">
          <Icon name="skip-forward" :size="21" />
        </button>
        <button
          class="icon-btn"
          :aria-pressed="state.repeat !== 'off'"
          :aria-label="repeatLabel"
          :title="repeatLabel + (store.shared.value ? '' : ' (R)')"
          :disabled="store.shared.value"
          @click="store.cycleRepeat()"
        >
          <Icon :name="state.repeat === 'one' ? 'repeat-1' : 'repeat'" :size="18" />
        </button>
      </div>

      <div class="timeline">
        <span class="time" aria-hidden="true">{{ formatTime(shownProgress) }}</span>
        <input
          class="range seek"
          type="range"
          min="0"
          :max="duration || 1"
          step="1"
          :value="shownProgress"
          :style="{ '--pct': pct(shownProgress, duration) }"
          :disabled="!song"
          aria-label="Seek"
          :aria-valuetext="`${formatTime(shownProgress)} of ${formatTime(duration)}`"
          @input="onSeekInput"
          @change="onSeekCommit"
        />
        <button
          class="time end"
          :aria-label="settings.showRemaining ? 'Showing time remaining. Show total length' : 'Showing total length. Show time remaining'"
          @click="settings.showRemaining = !settings.showRemaining"
        >
          {{ settings.showRemaining && song ? `-${formatTime(duration - shownProgress)}` : formatTime(duration) }}
        </button>
      </div>
    </div>

    <div class="tools">
      <LightSync v-if="store.lightSync.value" />

      <div class="sleep-wrap">
        <button
          ref="sleepBtn"
          class="icon-btn"
          :class="{ on: sleepActive }"
          aria-haspopup="menu"
          :aria-expanded="sleepOpen"
          :aria-label="sleepActive ? `Sleep timer, ${sleepBadge} left` : 'Sleep timer'"
          title="Sleep timer"
          @click="toggleSleep"
        >
          <Icon name="moon" :size="18" />
          <span v-if="sleepBadge" class="badge" aria-hidden="true">{{ sleepBadge }}</span>
        </button>
        <Transition name="pop">
          <div v-if="sleepOpen" ref="sleepMenu" class="popover" role="menu" aria-label="Sleep timer" @keydown="onMenuKey">
            <p class="pop-title">Stop playing after…</p>
            <button
              v-for="o in sleepOptions"
              :key="o.label"
              class="pop-item"
              role="menuitemradio"
              :aria-checked="isSelected(o.value)"
              @click="store.setSleepTimer(o.value)"
            >
              <span>{{ o.label }}</span>
              <Icon v-if="isSelected(o.value)" name="check" :size="15" />
            </button>
          </div>
        </Transition>
      </div>

      <button
        class="icon-btn"
        :aria-pressed="state.view === 'queue'"
        aria-label="Queue"
        title="Queue (Q)"
        @click="store.setView(state.view === 'queue' ? 'home' : 'queue')"
      >
        <Icon name="list-music" :size="19" />
      </button>
      <button
        class="icon-btn"
        :aria-pressed="settings.nowPlayingPanel"
        aria-label="Now playing panel"
        title="Now playing panel (N)"
        @click="settings.nowPlayingPanel = !settings.nowPlayingPanel"
      >
        <Icon name="panel-right" :size="19" />
      </button>

      <div class="volume" @wheel.prevent="onWheel">
        <button
          class="icon-btn"
          :aria-label="state.muted ? 'Unmute' : 'Mute'"
          :title="(state.muted ? 'Unmute' : 'Mute') + ' (M)'"
          @click="store.toggleMute"
        >
          <Icon :name="volumeIcon" :size="19" />
        </button>
        <input
          class="range vol"
          type="range"
          min="0"
          max="100"
          step="1"
          :value="volume"
          :style="{ '--pct': pct(volume, 100) }"
          aria-label="Volume"
          :aria-valuetext="`${volume}%`"
          @input="onVolumeInput"
        />
        <span class="vol-num" aria-hidden="true">{{ volume }}</span>
      </div>
    </div>
  </footer>
</template>

<style scoped>
.dock {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(34rem, 1.5fr) minmax(0, 1fr);
  align-items: center;
  gap: 2rem;
  padding: 1.2rem 1.8rem 1.2rem 1.2rem;
  min-height: 9.2rem;
}

.now {
  display: flex;
  align-items: center;
  gap: 1.3rem;
  min-width: 0;
}

.now-art {
  position: relative;
  border-radius: 1.2rem;
  box-shadow: 0 0.8rem 2rem -0.8rem rgba(0, 0, 0, 0.7);
}

.now-art-hint {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 1.2rem;
  background: rgba(8, 6, 10, 0.55);
  color: #fff;
  opacity: 0;
  transition: opacity 0.15s var(--ease);
}

.now-art:hover .now-art-hint,
.now-art:focus-visible .now-art-hint {
  opacity: 1;
}

.now-meta {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.now-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--text-h);
}

.now-title.muted {
  color: var(--text-dim);
}

.now-artist {
  font-size: 1.25rem;
  color: var(--text-dim);
}

.center {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.6rem;
  min-width: 0;
}

.transport {
  display: flex;
  align-items: center;
  gap: 0.6rem;
}

.transport .icon-btn.lg {
  color: var(--text-h);
}

.main-play {
  width: 4.8rem;
  height: 4.8rem;
  margin: 0 0.6rem;
}

.timeline {
  display: flex;
  align-items: center;
  gap: 1rem;
  width: 100%;
}

.time {
  width: 4.6rem;
  flex-shrink: 0;
  font-size: 1.2rem;
  font-weight: 600;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
  text-align: right;
}

.time.end {
  text-align: left;
  border-radius: var(--r-xs);
  transition: color 0.15s var(--ease);
}

.time.end:hover {
  color: var(--text-h);
}

.seek {
  flex: 1;
}

.timeline:hover .seek::-webkit-slider-runnable-track {
  height: 0.6rem;
}

.tools {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.2rem;
  min-width: 0;
}

.sleep-wrap {
  position: relative;
}

.badge {
  position: absolute;
  top: -0.2rem;
  right: -0.4rem;
  min-width: 2rem;
  padding: 0.1rem 0.5rem;
  border-radius: var(--r-pill);
  background: var(--accent);
  color: var(--on-accent);
  font-size: 0.95rem;
  font-weight: 800;
  line-height: 1.5;
}

.popover {
  position: absolute;
  bottom: calc(100% + 1.4rem);
  right: -6rem;
  z-index: 50;
  width: 22rem;
  padding: 0.6rem;
  border-radius: var(--r-lg);
  background: var(--panel-raised);
  border: 0.1rem solid var(--line-2);
  box-shadow: var(--shadow-pop);
  transform-origin: bottom center;
}

.pop-title {
  padding: 0.8rem 1rem 0.6rem;
  font-size: 1.15rem;
  font-weight: 750;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--text-faint);
}

.pop-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  height: 3.6rem;
  padding: 0 1rem;
  border-radius: var(--r-sm);
  font-size: 1.35rem;
  font-weight: 600;
  color: var(--text);
}

.pop-item:hover,
.pop-item:focus-visible {
  background: var(--fill-2);
  color: var(--text-h);
  outline: none;
}

.pop-item[aria-checked='true'] {
  color: var(--accent);
}

.volume {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  margin-left: 0.4rem;
}

.vol {
  width: 10rem;
}

.vol-num {
  width: 2.8rem;
  font-size: 1.15rem;
  font-weight: 650;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
  text-align: right;
}
</style>
