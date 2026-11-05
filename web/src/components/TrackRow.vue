<script setup lang="ts">
import { computed } from 'vue'
import type { PlayingFrom, Song } from '../types'
import { store } from '../store'
import { anchorBelow, anchorFrom } from '../utils/menu'
import Icon from './Icon.vue'
import Cover from './Cover.vue'

const props = withDefaults(
  defineProps<{
    song: Song
    index: number
    context: Song[]
    contextPlaylistId?: string | number
    from?: PlayingFrom | null
  }>(),
  { from: null },
)

const isCurrent = computed(() => store.currentSong.value?.id === props.song.id)
const isLive = computed(() => isCurrent.value && store.state.isPlaying)
const liked = computed(() => store.isFavorite(props.song.id))

function play() {
  if (isCurrent.value) store.togglePlay()
  else store.playSong(props.song, props.context, props.from)
}

function openMenu(e: MouseEvent) {
  store.openTrackMenu(props.song.id, anchorFrom(e), props.contextPlaylistId)
}

function onKey(e: KeyboardEvent) {
  const row = e.currentTarget as HTMLElement
  if (e.target !== row) return
  const handled = () => {
    e.preventDefault()
    e.stopPropagation()
  }

  if (e.key === 'Enter' || e.key === ' ') {
    handled()
    play()
  } else if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
    handled()
    const rows = Array.from(row.closest('[data-tracklist]')?.querySelectorAll<HTMLElement>('.track-row') ?? [])
    const i = rows.indexOf(row) + (e.key === 'ArrowDown' ? 1 : -1)
    rows[Math.max(0, Math.min(rows.length - 1, i))]?.focus()
  } else if (e.key === 'ContextMenu' || (e.shiftKey && e.key === 'F10')) {
    handled()
    store.openTrackMenu(props.song.id, anchorBelow(row), props.contextPlaylistId)
  }
}

const label = computed(
  () =>
    `${props.song.title} by ${props.song.artist}, ${store.formatTime(props.song.duration)}` +
    (isCurrent.value ? (isLive.value ? ', now playing' : ', paused') : ''),
)
</script>

<template>
  <div
    class="track-row"
    :class="{ current: isCurrent, live: isLive }"
    tabindex="0"
    :aria-label="label"
    @dblclick="play"
    @keydown="onKey"
    @contextmenu.prevent="openMenu"
  >
    <span class="idx" aria-hidden="true">
      <span class="num">{{ index + 1 }}</span>
      <span class="eq" :class="{ live: isLive }"><i /><i /><i /><i /></span>
    </span>

    <button class="art" tabindex="-1" :aria-label="isLive ? 'Pause' : `Play ${song.title}`" @click.stop="play">
      <Cover :src="song.thumbnail ?? null" :hue="song.hue" :size="44" :radius="8" />
      <span class="art-overlay"><Icon :name="isLive ? 'pause' : 'play'" :size="17" /></span>
    </button>

    <span class="meta">
      <span class="title truncate">{{ song.title }}</span>
      <span class="artist truncate">{{ song.artist }}</span>
    </span>

    <span class="actions">
      <button
        class="icon-btn sm like"
        :class="{ liked, reveal: !liked }"
        tabindex="-1"
        :aria-label="liked ? 'Remove from Liked Songs' : 'Add to Liked Songs'"
        :title="liked ? 'Remove from Liked Songs' : 'Add to Liked Songs'"
        @click.stop="store.toggleFavorite(song.id)"
      >
        <Icon name="heart" :size="16" :filled="liked" />
      </button>
      <button
        class="icon-btn sm reveal"
        tabindex="-1"
        aria-label="Add to queue"
        title="Add to queue"
        @click.stop="store.addToQueue(song)"
      >
        <Icon name="list-plus" :size="17" />
      </button>
    </span>

    <span class="dur">{{ store.formatTime(song.duration) }}</span>

    <button class="icon-btn sm reveal" tabindex="-1" aria-label="More options" title="More options" @click.stop="openMenu">
      <Icon name="more-horizontal" :size="18" />
    </button>
  </div>
</template>

<style scoped>
.track-row {
  display: grid;
  grid-template-columns: 3rem 4.4rem minmax(0, 1fr) auto 5rem 3rem;
  align-items: center;
  gap: 1.2rem;
  padding: var(--row-pad) 1rem;
  border-radius: var(--r-md);
  cursor: default;
  user-select: none;
  transition: background-color 0.14s var(--ease);
}

.track-row:hover {
  background: var(--fill-2);
}

.track-row:focus-visible {
  outline-offset: -0.2rem;
  background: var(--fill-2);
}

.track-row.current {
  background: var(--accent-soft);
}

.idx {
  display: grid;
  place-items: center;
  font-size: 1.35rem;
  font-weight: 600;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
}

.idx > * {
  grid-area: 1 / 1;
}

.idx .eq {
  opacity: 0;
}

.current .idx .num {
  opacity: 0;
}

.current .idx .eq {
  opacity: 1;
}

.art {
  position: relative;
  display: block;
  border-radius: 0.8rem;
}

.art-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 0.8rem;
  background: rgba(8, 6, 10, 0.55);
  color: #fff;
  opacity: 0;
  transition: opacity 0.14s var(--ease);
}

.track-row:hover .art-overlay,
.track-row:focus-visible .art-overlay {
  opacity: 1;
}

.meta {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.title {
  font-size: 1.45rem;
  font-weight: 650;
  color: var(--text-h);
}

.current .title {
  color: var(--accent);
}

.artist {
  font-size: 1.25rem;
  color: var(--text-dim);
}

.actions {
  display: flex;
  gap: 0.2rem;
}

.dur {
  font-size: 1.3rem;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
  text-align: right;
}

.reveal {
  opacity: 0;
}

.track-row:hover .reveal,
.track-row:focus-visible .reveal,
.track-row:focus-within .reveal {
  opacity: 1;
}

.like::after {
  display: none;
}
</style>
