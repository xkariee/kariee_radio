<script setup lang="ts">
import type { Song } from '../types'
import { store } from '../store'
import Icon from './Icon.vue'
import Cover from './Cover.vue'

const props = defineProps<{
  song: Song
  index: number
  context: Song[]
  contextPlaylistId?: string
}>()

const isCurrent = () => store.currentSong.value?.id === props.song.id

function handlePlayClick() {
  if (isCurrent()) store.togglePlay()
  else store.playSong(props.song, props.context)
}

function openMenu(e: MouseEvent) {
  e.stopPropagation()
  const rect = (e.currentTarget as HTMLElement).getBoundingClientRect()
  store.openTrackMenu(props.song.id, rect.right, rect.top, props.contextPlaylistId)
}
</script>

<template>
  <div
    class="track-row"
    :class="{ current: isCurrent(), playing: isCurrent() && store.state.isPlaying }"
    @dblclick="store.playSong(song, context)"
  >
    <div class="idx-cell">
      <span class="idx">{{ index + 1 }}</span>
      <span class="eq-bars"><span /><span /><span /></span>
      <button
        class="play-hover"
        :title="isCurrent() && store.state.isPlaying ? 'Pause' : 'Play'"
        @click="handlePlayClick"
      >
        <Icon :name="isCurrent() && store.state.isPlaying ? 'pause' : 'play'" :size="13" />
      </button>
    </div>
    <Cover :src="song.thumbnail ?? null" :hue="song.hue" :size="34" :radius="6" />
    <div class="meta">
      <span class="title">{{ song.title }}</span>
      <span class="artist">{{ song.artist }}</span>
    </div>
    <button
      class="row-action fav-btn"
      :class="{ active: store.isFavorite(song.id) }"
      title="Toggle favourite"
      @click.stop="store.toggleFavorite(song.id)"
    >
      <Icon name="heart" :size="14" :filled="store.isFavorite(song.id)" />
    </button>
    <button
      class="row-action"
      title="Add to queue"
      @click.stop="store.addToQueue(song)"
    >
      <Icon name="list-plus" :size="15" />
    </button>
    <span class="duration">{{ store.formatTime(song.duration) }}</span>
    <button class="row-action" title="More" @click="openMenu">
      <Icon name="more-horizontal" :size="16" />
    </button>
  </div>
</template>

<style scoped>
.track-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 7px 10px;
  border-radius: var(--radius-sm);
  transition: background-color 0.15s var(--ease);
}

.track-row:hover {
  background: var(--surface-2);
}

.track-row.current .title {
  color: var(--teal);
}

.idx-cell {
  width: 22px;
  height: 16px;
  flex-shrink: 0;
  display: grid;
  place-items: center;
}

.idx-cell > * {
  grid-area: 1 / 1;
}

.idx {
  font-size: 12.5px;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
  transition: opacity 0.1s var(--ease);
}

.track-row.current .idx,
.track-row:hover .idx {
  opacity: 0;
}

.eq-bars {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 2px;
  height: 13px;
  opacity: 0;
  transition: opacity 0.1s var(--ease);
}

.track-row.current .eq-bars {
  opacity: 1;
}

.track-row:hover .eq-bars {
  opacity: 0;
}

.eq-bars span {
  width: 3px;
  border-radius: 1px;
  background: var(--teal);
  transform: scaleY(0.35);
  transform-origin: bottom;
}

.track-row.playing .eq-bars span {
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

.play-hover {
  opacity: 0;
  color: var(--text-h);
  transition: opacity 0.1s var(--ease);
}

.track-row:hover .play-hover {
  opacity: 1;
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
  transition: color 0.15s var(--ease);
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
  width: 38px;
  text-align: right;
  flex-shrink: 0;
}

.row-action {
  color: var(--text-faint);
  opacity: 0;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  border-radius: var(--radius-sm);
  transition:
    opacity 0.12s var(--ease),
    background-color 0.12s var(--ease),
    color 0.12s var(--ease),
    transform 0.12s var(--ease);
}

.track-row:hover .row-action {
  opacity: 1;
}

.row-action:hover {
  background: var(--surface-3);
  color: var(--text);
  transform: scale(1.08);
}

.fav-btn.active {
  opacity: 1;
  color: var(--pink);
}

.fav-btn.active svg {
  animation: heart-pop 0.3s var(--ease);
}

@keyframes heart-pop {
  0% {
    transform: scale(1);
  }
  35% {
    transform: scale(1.35);
  }
  100% {
    transform: scale(1);
  }
}
</style>
