<script setup lang="ts">
import { store } from '../store'
import Icon from './Icon.vue'
import Cover from './Cover.vue'
</script>

<template>
  <div class="queue-view">
    <div class="library-header">
      <h1>Queue</h1>
    </div>

    <div v-if="store.currentSong.value" class="now-block">
      <span class="section-label">Now Playing</span>
      <div class="now-row" :class="{ live: store.state.isPlaying }">
        <Cover :src="store.currentSong.value.thumbnail ?? null" :hue="store.currentSong.value.hue" :size="44" :radius="8" />
        <div class="meta">
          <span class="title">{{ store.currentSong.value.title }}</span>
          <span class="artist">{{ store.currentSong.value.artist }}</span>
        </div>
        <span class="badge">
          <span class="eq-bars" :class="{ animate: store.state.isPlaying }"><span /><span /><span /></span>
          {{ store.state.isPlaying ? 'Playing' : 'Paused' }}
        </span>
      </div>
    </div>

    <div class="up-next">
      <span class="section-label">Up Next</span>
      <div v-if="!store.upNext.value.length" class="empty">
        <span class="empty-badge">
          <Icon name="list-music" :size="22" />
        </span>
        <p>Queue is empty. Search for a song or open a playlist to add some.</p>
      </div>
      <TransitionGroup v-else name="list" tag="div" class="track-list">
        <div v-for="entry in store.upNext.value" :key="entry.qid" class="queue-row">
          <Cover
            :src="store.songById(entry.songId)?.thumbnail ?? null"
            :hue="store.songById(entry.songId)?.hue ?? 0"
            :size="34"
            :radius="6"
          />
          <div class="meta">
            <span class="title">{{ store.songById(entry.songId)?.title }}</span>
            <span class="artist">{{ store.songById(entry.songId)?.artist }}</span>
          </div>
          <span class="duration">{{ store.formatTime(store.songById(entry.songId)?.duration ?? 0) }}</span>
          <button class="row-action" title="Remove from queue" @click="store.removeFromQueue(entry.qid)">
            <Icon name="x" :size="15" />
          </button>
        </div>
      </TransitionGroup>
    </div>
  </div>
</template>

<style scoped>
.queue-view {
  display: flex;
  flex-direction: column;
  gap: 22px;
}

.library-header h1 {
  font-size: 19px;
  font-weight: 600;
  color: var(--text-h);
  margin: 0;
}

.section-label {
  display: block;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--text-faint);
  margin-bottom: 8px;
}

.now-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 12px;
  border-radius: var(--radius-md);
  background: var(--surface-2);
  border: 1px solid var(--line);
  transition:
    background-color 0.2s var(--ease),
    border-color 0.2s var(--ease);
}

.now-row.live {
  background: var(--teal-wash);
  border-color: var(--teal-line);
  box-shadow: 0 0 0 3px rgba(45, 212, 191, 0.06);
}

.badge {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
  font-weight: 600;
  color: var(--text-faint);
  margin-left: auto;
  flex-shrink: 0;
}

.now-row.live .badge {
  color: var(--teal);
}

.eq-bars {
  display: flex;
  align-items: flex-end;
  gap: 2px;
  height: 11px;
}

.eq-bars span {
  width: 2.5px;
  border-radius: 1px;
  background: currentColor;
  transform: scaleY(0.35);
  transform-origin: bottom;
}

.eq-bars.animate span {
  animation: eq-bounce 0.9s ease-in-out infinite;
}

.eq-bars span:nth-child(1) {
  animation-delay: -0.6s;
}

.eq-bars span:nth-child(2) {
  animation-delay: -0.2s;
}

.eq-bars span:nth-child(3) {
  animation-delay: -0.9s;
}

@keyframes eq-bounce {
  0%,
  100% {
    transform: scaleY(0.35);
  }
  50% {
    transform: scaleY(1);
  }
}

.meta {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.title {
  font-size: 13.5px;
  font-weight: 500;
  color: var(--text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.artist {
  font-size: 12px;
  color: var(--text-faint);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.duration {
  font-size: 12px;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
  flex-shrink: 0;
}

.track-list {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.queue-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 6px 10px;
  border-radius: var(--radius-sm);
  transition: background-color 0.15s var(--ease);
}

.queue-row:hover {
  background: var(--surface-2);
}

.row-action {
  color: var(--text-faint);
  opacity: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  border-radius: var(--radius-sm);
  flex-shrink: 0;
  transition:
    opacity 0.12s var(--ease),
    background-color 0.12s var(--ease),
    color 0.12s var(--ease),
    transform 0.12s var(--ease);
}

.queue-row:hover .row-action {
  opacity: 1;
}

.row-action:hover {
  background: var(--surface-3);
  color: var(--danger);
  transform: scale(1.08);
}

.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  color: var(--text-faint);
  padding: 32px 0;
  font-size: 13px;
  text-align: center;
}

.empty-badge {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 52px;
  height: 52px;
  border-radius: 50%;
  background: var(--surface-2);
  border: 1px solid var(--line);
  color: var(--text-faint);
}

.list-move,
.list-enter-active,
.list-leave-active {
  transition:
    transform 0.2s var(--ease),
    opacity 0.2s var(--ease);
}

.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(-8px);
}

.list-leave-active {
  position: absolute;
  width: 100%;
}
</style>
