<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { store } from '../store'
import Icon from './Icon.vue'

const menuEl = ref<HTMLElement | null>(null)

const song = computed(() => (store.state.menu?.kind === 'track' ? store.songById(store.state.menu.trackId) : null))
const playlist = computed(() =>
  store.state.menu?.kind === 'playlist' && store.state.menu.playlistId
    ? store.playlistById(store.state.menu.playlistId)
    : null,
)
const contextPlaylistId = computed(() => store.state.menu?.kind === 'track' ? store.state.menu.contextPlaylistId : undefined)

const style = computed(() => {
  const m = store.state.menu
  if (!m) return {}
  const width = 230
  const left = Math.min(m.x - width, window.innerWidth - width - 8)
  const top = Math.min(m.y, window.innerHeight - 320)
  return { left: `${Math.max(8, left)}px`, top: `${Math.max(8, top)}px` }
})

function onDocClick(e: MouseEvent) {
  if (menuEl.value && !menuEl.value.contains(e.target as Node)) store.closeMenu()
}
function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape') store.closeMenu()
}
onMounted(() => {
  document.addEventListener('mousedown', onDocClick)
  document.addEventListener('keydown', onKey)
})
onUnmounted(() => {
  document.removeEventListener('mousedown', onDocClick)
  document.removeEventListener('keydown', onKey)
})

function addToQueue() {
  if (song.value) store.addToQueue(song.value)
  store.closeMenu()
}
function playNext() {
  if (song.value) store.playNext(song.value)
  store.closeMenu()
}
function toggleInPlaylist(playlistId: string) {
  if (song.value) store.toggleSongInPlaylist(playlistId, song.value.id)
}
function removeFromThisPlaylist() {
  if (song.value && contextPlaylistId.value) store.removeSongFromPlaylist(contextPlaylistId.value, song.value.id)
  store.closeMenu()
}
function playPlaylist() {
  const pl = playlist.value
  if (!pl) return
  const list = pl.songIds.map((id) => store.songById(id)).filter((s): s is NonNullable<typeof s> => !!s)
  if (list.length) store.playSong(list[0], list)
  store.closeMenu()
}
function invitePlaylist() {
  if (playlist.value) store.state.inviteePlaylistId = playlist.value.id
  store.closeMenu()
}
function editPlaylist() {
  if (playlist.value) store.state.editPlaylistId = playlist.value.id
  store.closeMenu()
}
function deletePlaylist() {
  if (playlist.value) store.requestDeletePlaylist(playlist.value.id)
  store.closeMenu()
}
</script>

<template>
  <Transition name="pop">
  <div v-if="store.state.menu" ref="menuEl" class="context-menu" :style="style">
    <template v-if="song">
      <button class="menu-item" @click="addToQueue">
        <Icon name="list-plus" :size="14" /> Add to Queue
      </button>
      <button class="menu-item" @click="playNext">
        <Icon name="skip-forward" :size="14" /> Play Next
      </button>
      <button v-if="contextPlaylistId" class="menu-item danger" @click="removeFromThisPlaylist">
        <Icon name="x" :size="14" /> Remove from Playlist
      </button>
      <div class="menu-divider" />
      <span class="menu-label">Add to Playlist</span>
      <div class="menu-scroll">
        <button
          v-for="pl in store.state.playlists"
          :key="pl.id"
          class="menu-item"
          @click="toggleInPlaylist(pl.id)"
        >
          <span class="check-box" :class="{ on: store.isInPlaylist(pl.id, song.id) }">
            <Icon v-if="store.isInPlaylist(pl.id, song.id)" name="check" :size="11" />
          </span>
          <span class="truncate">{{ pl.name }}</span>
        </button>
      </div>
      <div class="menu-divider" />
      <button class="menu-item" @click="store.state.createPlaylistOpen = true; store.closeMenu()">
        <Icon name="plus" :size="14" /> New Playlist
      </button>
    </template>

    <template v-else-if="playlist">
      <button class="menu-item" @click="playPlaylist">
        <Icon name="play" :size="14" /> Play
      </button>
      <template v-if="!playlist.isDefault">
        <button class="menu-item" @click="invitePlaylist">
          <Icon name="user-plus" :size="14" /> Invite People
        </button>
        <button class="menu-item" @click="editPlaylist">
          <Icon name="edit-2" :size="14" /> Rename &amp; Edit Cover
        </button>
        <div class="menu-divider" />
        <button class="menu-item danger" @click="deletePlaylist">
          <Icon name="trash-2" :size="14" /> Delete Playlist
        </button>
      </template>
    </template>
  </div>
  </Transition>
</template>

<style scoped>
.context-menu {
  position: fixed;
  width: 230px;
  background: var(--surface-2);
  border: 1px solid var(--line);
  border-radius: var(--radius-md);
  padding: 6px;
  box-shadow: var(--shadow-lg);
  z-index: 200;
  display: flex;
  flex-direction: column;
  gap: 1px;
  transform-origin: top right;
}

.menu-item {
  display: flex;
  align-items: center;
  gap: 9px;
  width: 100%;
  padding: 7px 8px;
  border-radius: var(--radius-sm);
  font-size: 12.5px;
  color: var(--text);
  text-align: left;
  transition: background-color 0.12s var(--ease);
}

.menu-item:hover {
  background: var(--surface-3);
}

.menu-item > svg {
  color: var(--text-faint);
  transition: color 0.12s var(--ease);
}

.menu-item:hover > svg {
  color: var(--teal);
}

.menu-item.danger:hover > svg {
  color: var(--danger);
}

.menu-item.danger {
  color: #f87171;
}

.menu-label {
  font-size: 10.5px;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--text-faint);
  padding: 6px 8px 2px;
}

.menu-scroll {
  max-height: 140px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.menu-divider {
  height: 1px;
  background: var(--line);
  margin: 4px 2px;
}

.check-box {
  width: 15px;
  height: 15px;
  border-radius: 4px;
  border: 1px solid var(--line);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: #08201d;
  transition:
    background-color 0.12s var(--ease),
    border-color 0.12s var(--ease);
}

.check-box.on {
  background: var(--teal);
  border-color: var(--teal);
}

.truncate {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
