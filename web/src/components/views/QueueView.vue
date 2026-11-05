<script setup lang="ts">
import { computed, ref } from 'vue'
import { store } from '../../store'
import { anchorFrom } from '../../utils/menu'
import Icon from '../Icon.vue'
import Cover from '../Cover.vue'

const { state } = store

const song = store.currentSong
const upNext = store.upNext

const upNextLength = computed(() =>
  upNext.value.reduce((sum, e) => sum + (store.songById(e.songId)?.duration ?? 0), 0),
)

const sharedNote = computed(() =>
  state.contextKind === 'radiocar'
    ? 'Everyone in this vehicle sees and edits this queue.'
    : 'Everyone at this booth sees and edits this queue.',
)

const dragFrom = ref<number | null>(null)
const dragOver = ref<number | null>(null)

function onDragStart(e: DragEvent, i: number) {
  dragFrom.value = i
  e.dataTransfer?.setData('text/plain', String(i))
  if (e.dataTransfer) e.dataTransfer.effectAllowed = 'move'
}

function onDragOver(e: DragEvent, i: number) {
  if (dragFrom.value === null) return
  e.preventDefault()
  dragOver.value = i
}

function onDrop(i: number) {
  if (dragFrom.value !== null) store.reorderUpNext(dragFrom.value, i)
  dragFrom.value = dragOver.value = null
}

function onDragEnd() {
  dragFrom.value = dragOver.value = null
}

const announce = ref('')

function move(i: number, delta: number, focusRow = false) {
  const to = i + delta
  if (to < 0 || to >= upNext.value.length) return
  const title = store.songById(upNext.value[i].songId)?.title ?? 'Song'
  store.reorderUpNext(i, to)
  announce.value = `${title} moved to position ${to + 1}`
  if (focusRow) requestAnimationFrame(() => document.querySelectorAll<HTMLElement>('.q-row')[to]?.focus())
}

function onRowKey(e: KeyboardEvent, i: number, qid: string) {
  if (e.target !== e.currentTarget) return
  if (e.altKey && (e.key === 'ArrowUp' || e.key === 'ArrowDown')) {
    e.preventDefault()
    e.stopPropagation()
    move(i, e.key === 'ArrowUp' ? -1 : 1, true)
  } else if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
    e.preventDefault()
    e.stopPropagation()
    const rows = document.querySelectorAll<HTMLElement>('.q-row')
    rows[Math.max(0, Math.min(rows.length - 1, i + (e.key === 'ArrowDown' ? 1 : -1)))]?.focus()
  } else if (e.key === 'Enter') {
    e.preventDefault()
    e.stopPropagation()
    store.jumpTo(qid)
  } else if (e.key === 'Delete' || e.key === 'Backspace') {
    e.preventDefault()
    e.stopPropagation()
    store.removeFromQueue(qid)
  }
}
</script>

<template>
  <div class="queue">
    <header class="head">
      <div>
        <p class="eyebrow">{{ store.shared.value ? 'Shared queue' : 'Your queue' }}</p>
        <h1 class="view-title">Queue</h1>
      </div>
      <div class="head-actions">
        <button class="btn btn-secondary sm" :disabled="upNext.length < 2" @click="store.shuffleUpNext()">
          <Icon name="shuffle" :size="15" /> Shuffle up next
        </button>
        <button class="btn btn-quiet sm" :disabled="!upNext.length" @click="store.clearUpNext()">
          <Icon name="trash-2" :size="15" /> Clear
        </button>
      </div>
    </header>

    <p v-if="store.shared.value" class="shared-note"><Icon name="users" :size="15" /> {{ sharedNote }}</p>

    <section v-if="song" aria-labelledby="np-label">
      <h2 id="np-label" class="eyebrow label">Now playing</h2>
      <div class="now" :class="{ live: state.isPlaying }" @contextmenu.prevent="store.openTrackMenu(song.id, anchorFrom($event))">
        <button class="now-art" :aria-label="state.isPlaying ? 'Pause' : 'Play'" @click="store.togglePlay()">
          <Cover :src="song.thumbnail ?? null" :hue="song.hue" :size="72" :radius="12" />
          <span class="now-overlay"><Icon :name="state.isPlaying ? 'pause' : 'play'" :size="22" /></span>
        </button>
        <div class="now-meta">
          <span class="now-title truncate">{{ song.title }}</span>
          <span class="now-artist truncate">{{ song.artist }}</span>
          <span v-if="state.playingFrom" class="now-from truncate">Playing from {{ state.playingFrom.label }}</span>
        </div>
        <span class="eq" :class="{ live: state.isPlaying }" aria-hidden="true"><i /><i /><i /><i /></span>
        <button
          class="icon-btn"
          :class="{ liked: store.isFavorite(song.id) }"
          :aria-label="store.isFavorite(song.id) ? 'Remove from Liked Songs' : 'Add to Liked Songs'"
          @click="store.toggleFavorite(song.id)"
        >
          <Icon name="heart" :size="19" :filled="store.isFavorite(song.id)" />
        </button>
      </div>
    </section>

    <section aria-labelledby="next-label">
      <div class="next-head">
        <h2 id="next-label" class="eyebrow label">Next up</h2>
        <span v-if="upNext.length" class="next-stats">
          {{ upNext.length }} song{{ upNext.length === 1 ? '' : 's' }} · {{ store.formatLength(upNextLength) }}
        </span>
      </div>

      <div v-if="!upNext.length" class="empty-state">
        <span class="badge"><Icon name="list-music" :size="26" /></span>
        <h3>Nothing queued</h3>
        <p>Add songs from any list with the <Icon name="list-plus" :size="14" class="inline" /> button, or “Add to queue” in a song’s menu.</p>
      </div>

      <ol v-else class="q-list" aria-describedby="q-help">
        <li
          v-for="(entry, i) in upNext"
          :key="entry.qid"
          class="q-row"
          :class="{ dragging: dragFrom === i, over: dragOver === i && dragFrom !== i, above: dragFrom !== null && i < dragFrom }"
          tabindex="0"
          draggable="true"
          :aria-label="`${i + 1}. ${store.songById(entry.songId)?.title} by ${store.songById(entry.songId)?.artist}`"
          @dragstart="onDragStart($event, i)"
          @dragover="onDragOver($event, i)"
          @drop.prevent="onDrop(i)"
          @dragend="onDragEnd"
          @dblclick="store.jumpTo(entry.qid)"
          @keydown="onRowKey($event, i, entry.qid)"
        >
          <span class="grip" aria-hidden="true"><Icon name="grip" :size="16" /></span>
          <span class="q-idx" aria-hidden="true">{{ i + 1 }}</span>
          <button class="q-art" tabindex="-1" :aria-label="`Play now`" @click="store.jumpTo(entry.qid)">
            <Cover
              :src="store.songById(entry.songId)?.thumbnail ?? null"
              :hue="store.songById(entry.songId)?.hue ?? 0"
              :size="40"
              :radius="8"
            />
            <span class="q-overlay"><Icon name="play" :size="14" /></span>
          </button>
          <span class="q-meta">
            <span class="q-title truncate">{{ store.songById(entry.songId)?.title }}</span>
            <span class="q-artist truncate">{{ store.songById(entry.songId)?.artist }}</span>
          </span>
          <span class="q-dur">{{ store.formatTime(store.songById(entry.songId)?.duration ?? 0) }}</span>
          <span class="q-actions">
            <button class="icon-btn sm" tabindex="-1" aria-label="Move up" title="Move up (Alt+↑)" :disabled="i === 0" @click="move(i, -1)">
              <Icon name="arrow-up" :size="15" />
            </button>
            <button
              class="icon-btn sm"
              tabindex="-1"
              aria-label="Move down"
              title="Move down (Alt+↓)"
              :disabled="i === upNext.length - 1"
              @click="move(i, 1)"
            >
              <Icon name="arrow-down" :size="15" />
            </button>
            <button class="icon-btn sm remove" tabindex="-1" aria-label="Remove from queue" title="Remove (Del)" @click="store.removeFromQueue(entry.qid)">
              <Icon name="x" :size="16" />
            </button>
          </span>
        </li>
      </ol>
      <p id="q-help" class="sr-only">
        Press Enter to play, Alt plus arrow keys to reorder, Delete to remove.
      </p>
      <p class="sr-only" role="status">{{ announce }}</p>
    </section>
  </div>
</template>

<style scoped>
.queue {
  display: flex;
  flex-direction: column;
  gap: 2.4rem;
  padding-top: 1.4rem;
}

.head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 1.6rem;
}

.head-actions {
  display: flex;
  gap: 0.6rem;
}

.shared-note {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  margin-top: -1.2rem;
  font-size: 1.3rem;
  color: var(--ok);
}

.label {
  margin-bottom: 1rem;
}

.now {
  display: flex;
  align-items: center;
  gap: 1.6rem;
  padding: 1.2rem 1.6rem 1.2rem 1.2rem;
  border-radius: var(--r-lg);
  background: var(--fill-2);
  border: 0.1rem solid var(--line);
  transition:
    background-color 0.3s var(--ease),
    border-color 0.3s var(--ease);
}

.now.live {
  background: linear-gradient(110deg, var(--accent-soft), var(--fill-1));
  border-color: var(--accent-line);
}

.now-art {
  position: relative;
  border-radius: 1.2rem;
}

.now-overlay,
.q-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: inherit;
  background: rgba(8, 6, 10, 0.55);
  color: #fff;
  opacity: 0;
  transition: opacity 0.14s var(--ease);
}

.now-art:hover .now-overlay,
.now-art:focus-visible .now-overlay {
  opacity: 1;
}

.now-meta {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.now-title {
  font-size: 1.8rem;
  font-weight: 750;
  color: var(--text-h);
}

.now-artist {
  font-size: 1.35rem;
  color: var(--text-dim);
}

.now-from {
  font-size: 1.2rem;
  color: var(--accent);
  font-weight: 600;
}

.next-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
}

.next-stats {
  font-size: 1.25rem;
  color: var(--text-faint);
}

.q-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: var(--row-gap);
}

.q-row {
  position: relative;
  display: grid;
  grid-template-columns: 2rem 2.4rem 4rem minmax(0, 1fr) 5rem auto;
  align-items: center;
  gap: 1.2rem;
  padding: var(--row-pad) 1rem;
  border-radius: var(--r-md);
  cursor: grab;
  transition:
    background-color 0.14s var(--ease),
    opacity 0.14s var(--ease);
}

.q-row:hover,
.q-row:focus-visible {
  background: var(--fill-2);
}

.q-row:focus-visible {
  outline-offset: -0.2rem;
}

.q-row.dragging {
  opacity: 0.4;
}

.q-row.over::after {
  content: '';
  position: absolute;
  left: 1rem;
  right: 1rem;
  bottom: -0.2rem;
  height: 0.3rem;
  border-radius: var(--r-pill);
  background: var(--accent);
  box-shadow: 0 0 1rem var(--accent-glow);
}

.q-row.over.above::after {
  bottom: auto;
  top: -0.2rem;
}

.grip {
  color: var(--text-faint);
  opacity: 0;
  transition: opacity 0.14s var(--ease);
}

.q-row:hover .grip,
.q-row:focus-visible .grip {
  opacity: 1;
}

.q-idx {
  text-align: center;
  font-size: 1.3rem;
  font-weight: 600;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
}

.q-art {
  position: relative;
  border-radius: 0.8rem;
}

.q-row:hover .q-overlay {
  opacity: 1;
}

.q-meta {
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.q-title {
  font-size: 1.4rem;
  font-weight: 650;
  color: var(--text-h);
}

.q-artist {
  font-size: 1.2rem;
  color: var(--text-dim);
}

.q-dur {
  text-align: right;
  font-size: 1.3rem;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
}

.q-actions {
  display: flex;
  gap: 0.2rem;
  opacity: 0;
  transition: opacity 0.14s var(--ease);
}

.q-row:hover .q-actions,
.q-row:focus-visible .q-actions,
.q-row:focus-within .q-actions {
  opacity: 1;
}

.remove:hover:not(:disabled) {
  background: var(--danger-soft);
  color: var(--danger);
}

.inline {
  display: inline-block;
  vertical-align: -0.2rem;
}
</style>
