<script setup lang="ts">
import { computed, ref } from 'vue'
import { store } from '../store'
import Icon from './Icon.vue'
import Cover from './Cover.vue'

const seeking = ref(false)
const seekValue = ref(0)

const duration = computed(() => store.currentSong.value?.duration ?? 0)
const displayProgress = computed(() => (seeking.value ? seekValue.value : store.state.progress))

function onSeekInput(e: Event) {
  seeking.value = true
  seekValue.value = Number((e.target as HTMLInputElement).value)
}

function onSeekCommit(e: Event) {
  const v = Number((e.target as HTMLInputElement).value)
  store.seek(v)
  seeking.value = false
}

function onVolumeInput(e: Event) {
  store.setVolume(Number((e.target as HTMLInputElement).value))
}

const volumeIcon = computed(() => {
  if (store.state.muted || store.state.volume === 0) return 'volume-x'
  if (store.state.volume < 50) return 'volume-1'
  return 'volume-2'
})

function fillStyle(value: number, max: number) {
  const pct = max > 0 ? Math.min(100, Math.max(0, (value / max) * 100)) : 0
  return {
    background: `linear-gradient(to right, var(--teal) ${pct}%, var(--surface-3) ${pct}%)`,
  }
}

const seekFillStyle = computed(() => fillStyle(displayProgress.value, duration.value))
const volumeFillStyle = computed(() => fillStyle(store.state.muted ? 0 : store.state.volume, 100))

function openMenu(e: MouseEvent) {
  const song = store.currentSong.value
  if (!song) return
  const rect = (e.currentTarget as HTMLElement).getBoundingClientRect()
  store.openTrackMenu(song.id, rect.right, rect.top)
}
</script>

<template>
  <footer class="player-bar">
    <div class="now-playing">
      <div v-if="store.currentSong.value" class="now-inner">
        <Cover :src="store.currentSong.value.thumbnail ?? null" :hue="store.currentSong.value.hue" :size="46" :radius="8" />
        <div class="meta">
          <span class="title">{{ store.currentSong.value.title }}</span>
          <span class="artist">{{ store.currentSong.value.artist }}</span>
        </div>
        <button
          class="btn-icon ghost fav-btn"
          :class="{ active: store.isFavorite(store.currentSong.value.id) }"
          title="Toggle favourite"
          @click="store.toggleFavorite(store.currentSong.value.id)"
        >
          <Icon name="heart" :size="15" :filled="store.isFavorite(store.currentSong.value.id)" />
        </button>
        <button class="btn-icon ghost" title="Add to playlist" @click="openMenu">
          <Icon name="folder-plus" :size="15" />
        </button>
      </div>
      <div v-else class="now-inner">
        <Cover :src="null" :hue="0" :size="46" :radius="8" />
        <div class="meta">
          <span class="title muted">Nothing playing</span>
          <span class="artist">Pick a song to get started</span>
        </div>
      </div>
    </div>

    <div class="transport">
      <div class="controls">
        <button class="btn-icon ghost" title="Previous" :disabled="!store.currentSong.value" @click="store.prev">
          <Icon name="skip-back" :size="17" />
        </button>
        <button
          class="btn-icon play-toggle"
          :disabled="!store.currentSong.value"
          @click="store.togglePlay"
        >
          <Icon :name="store.state.isPlaying ? 'pause' : 'play'" :size="16" />
        </button>
        <button class="btn-icon ghost" title="Next" :disabled="!store.currentSong.value" @click="store.next">
          <Icon name="skip-forward" :size="17" />
        </button>
      </div>
      <div class="timeline">
        <span class="time">{{ store.formatTime(displayProgress) }}</span>
        <input
          class="seek"
          type="range"
          min="0"
          :max="duration || 1"
          step="1"
          :value="displayProgress"
          :style="seekFillStyle"
          :disabled="!store.currentSong.value"
          @input="onSeekInput"
          @change="onSeekCommit"
        />
        <span class="time">{{ store.formatTime(duration) }}</span>
      </div>
    </div>

    <div class="volume">
      <button class="btn-icon ghost" @click="store.toggleMute" :title="store.state.muted ? 'Unmute' : 'Mute'">
        <Icon :name="volumeIcon" :size="17" />
      </button>
      <input
        class="volume-slider"
        type="range"
        min="0"
        max="100"
        step="1"
        :value="store.state.muted ? 0 : store.state.volume"
        :style="volumeFillStyle"
        @input="onVolumeInput"
      />
    </div>
  </footer>
</template>

<style scoped>
.player-bar {
  position: relative;
  display: grid;
  grid-template-columns: 1fr minmax(320px, 560px) 1fr;
  align-items: center;
  gap: 20px;
  padding: 12px 18px;
  background: var(--surface-1);
  flex-shrink: 0;
}

.player-bar::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 1px;
  background: linear-gradient(90deg, transparent, var(--line) 15%, var(--line) 85%, transparent);
}

.now-playing {
  min-width: 0;
}

.now-inner {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.fav-btn.active {
  color: var(--pink);
}

.meta {
  display: flex;
  flex-direction: column;
  gap: 1px;
  min-width: 0;
}

.title {
  font-size: 13.5px;
  font-weight: 500;
  color: var(--text-h);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.title.muted {
  color: var(--text-faint);
  font-weight: 400;
}

.artist {
  font-size: 12px;
  color: var(--text-faint);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.transport {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  min-width: 0;
}

.controls {
  display: flex;
  align-items: center;
  gap: 4px;
}

.controls .btn-icon.ghost:hover:not(:disabled) {
  transform: scale(1.1);
  color: var(--text-h);
}

.play-toggle {
  width: 34px;
  height: 34px;
  border-radius: 50%;
  margin: 0 6px;
  background: linear-gradient(155deg, var(--teal-hover), var(--teal-soft));
  color: #062420;
  box-shadow:
    0 1px 0 rgba(255, 255, 255, 0.3) inset,
    0 6px 16px -4px var(--teal-glow);
  transition:
    transform 0.15s var(--ease),
    box-shadow 0.15s var(--ease);
}

.play-toggle:hover:not(:disabled) {
  transform: scale(1.06);
  box-shadow:
    0 1px 0 rgba(255, 255, 255, 0.35) inset,
    0 8px 22px -4px var(--teal-glow);
}

.play-toggle:active:not(:disabled) {
  transform: scale(0.98);
}

.timeline {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
}

.time {
  font-size: 11px;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
  width: 32px;
  flex-shrink: 0;
}

.time:last-child {
  text-align: right;
}

.volume {
  display: flex;
  align-items: center;
  gap: 8px;
  justify-self: end;
  width: 150px;
}

.volume-slider {
  width: 100px;
}

/* range input styling shared by seek + volume */
input[type='range'] {
  -webkit-appearance: none;
  appearance: none;
  height: 4px;
  border-radius: 2px;
  background: var(--surface-3);
  outline: none;
  flex: 1;
  transition: height 0.12s var(--ease);
}

input[type='range']::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--teal);
  cursor: pointer;
  box-shadow: 0 0 0 0 rgba(45, 212, 191, 0.25);
  transition:
    transform 0.12s var(--ease),
    box-shadow 0.12s var(--ease);
}

input[type='range']:hover::-webkit-slider-thumb {
  transform: scale(1.3);
  box-shadow: 0 0 0 6px rgba(45, 212, 191, 0.18);
}

input[type='range']:active::-webkit-slider-thumb {
  transform: scale(1.15);
}

input[type='range']::-moz-range-thumb {
  width: 10px;
  height: 10px;
  border: none;
  border-radius: 50%;
  background: var(--teal);
  cursor: pointer;
  transition: transform 0.12s var(--ease);
}

input[type='range']:hover::-moz-range-thumb {
  transform: scale(1.3);
}

input[type='range']:disabled {
  opacity: 0.4;
}
</style>
