<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import type { Song } from '../types'
import { store } from '../store'
import Icon from './Icon.vue'
import Cover from './Cover.vue'

const { state } = store
const menuEl = ref<HTMLElement | null>(null)
const pos = ref({ left: -9999, top: -9999 })
let opener: HTMLElement | null = null

const song = computed(() => (state.menu?.kind === 'track' ? store.songById(state.menu.trackId) ?? null : null))
const playlist = computed(() =>
  state.menu?.kind === 'playlist' && state.menu.playlistId != null ? store.playlistById(state.menu.playlistId) ?? null : null,
)
const contextPlaylistId = computed(() => (state.menu?.kind === 'track' ? state.menu.contextPlaylistId : undefined))
const contextPlaylist = computed(() => (contextPlaylistId.value != null ? store.playlistById(contextPlaylistId.value) : null))

const otherPlaylists = computed(() => state.playlists.filter((p) => !p.isDefault))
const isCurrent = computed(() => !!song.value && store.currentSong.value?.id === song.value.id)

const items = () => Array.from(menuEl.value?.querySelectorAll<HTMLElement>('[role^="menuitem"]:not(:disabled)') ?? [])

watch(
  () => state.menu,
  async (m, old) => {
    if (m && !old) opener = document.activeElement as HTMLElement | null
    if (!m) {
      if (opener && document.contains(opener)) opener.focus({ preventScroll: true })
      opener = null
      return
    }
    pos.value = { left: -9999, top: -9999 }
    await nextTick()
    const el = menuEl.value
    if (!el) return
    const w = el.offsetWidth
    const h = el.offsetHeight
    let left = m.align === 'end' ? m.x - w : m.x
    let top = m.y
    if (top + h > window.innerHeight - 8) top = Math.max(8, window.innerHeight - h - 8)
    left = Math.max(8, Math.min(left, window.innerWidth - w - 8))
    pos.value = { left, top }
    items()[0]?.focus({ preventScroll: true })
  },
)

function onKey(e: KeyboardEvent) {
  const list = items()
  const i = list.indexOf(document.activeElement as HTMLElement)
  const go = (n: number) => {
    e.preventDefault()
    e.stopPropagation()
    list[(n + list.length) % list.length]?.focus()
  }
  if (e.key === 'ArrowDown') go(i + 1)
  else if (e.key === 'ArrowUp') go(i - 1)
  else if (e.key === 'Home') go(0)
  else if (e.key === 'End') go(list.length - 1)
  else if (e.key === 'Tab') {
    e.preventDefault()
    store.closeMenu()
  }
}

function onDocDown(e: MouseEvent) {
  if (state.menu && menuEl.value && !menuEl.value.contains(e.target as Node)) store.closeMenu()
}
function onScroll(e: Event) {
  if (state.menu && menuEl.value && !menuEl.value.contains(e.target as Node)) store.closeMenu()
}

onMounted(() => {
  document.addEventListener('mousedown', onDocDown)
  document.addEventListener('scroll', onScroll, true)
})
onUnmounted(() => {
  document.removeEventListener('mousedown', onDocDown)
  document.removeEventListener('scroll', onScroll, true)
})

function run(fn: () => void) {
  fn()
  store.closeMenu()
}

function playTrack(s: Song) {
  if (isCurrent.value) store.togglePlay()
  else store.playSong(s)
}

function playPlaylist(shuffle: boolean) {
  const pl = playlist.value
  if (!pl) return
  store.playList(store.playlistSongs(pl.id), { label: pl.name, nav: { view: 'playlist', playlistId: pl.id } }, { shuffle })
}
</script>

<template>
  <Transition name="pop">
    <div
      v-if="state.menu && (song || playlist)"
      ref="menuEl"
      class="menu"
      role="menu"
      :aria-label="song ? `Options for ${song.title}` : `Options for ${playlist?.name}`"
      :style="{ left: pos.left + 'px', top: pos.top + 'px' }"
      :class="{ 'from-end': state.menu.align === 'end' }"
      @keydown="onKey"
    >
      <template v-if="song">
        <div class="menu-head" aria-hidden="true">
          <Cover :src="song.thumbnail ?? null" :hue="song.hue" :size="40" :radius="8" />
          <span class="head-text">
            <span class="head-title truncate">{{ song.title }}</span>
            <span class="head-sub truncate">{{ song.artist }}</span>
          </span>
        </div>

        <button class="item" role="menuitem" @click="run(() => playTrack(song!))">
          <Icon :name="isCurrent && state.isPlaying ? 'pause' : 'play'" :size="16" />
          {{ isCurrent ? (state.isPlaying ? 'Pause' : 'Resume') : 'Play now' }}
        </button>
        <button class="item" role="menuitem" @click="run(() => store.playNext(song!))">
          <Icon name="skip-forward" :size="16" /> Play next
        </button>
        <button class="item" role="menuitem" @click="run(() => store.addToQueue(song!))">
          <Icon name="list-plus" :size="16" /> Add to queue
        </button>

        <div class="divider" role="separator" />

        <button class="item" role="menuitem" @click="run(() => store.toggleFavorite(song!.id))">
          <Icon name="heart" :size="16" :filled="store.isFavorite(song.id)" :class="{ liked: store.isFavorite(song.id) }" />
          {{ store.isFavorite(song.id) ? 'Remove from Liked Songs' : 'Add to Liked Songs' }}
        </button>
        <button
          v-if="contextPlaylist && !contextPlaylist.isDefault"
          class="item danger"
          role="menuitem"
          @click="run(() => store.removeSongFromPlaylist(contextPlaylistId!, song!.id))"
        >
          <Icon name="x" :size="16" /> Remove from this playlist
        </button>

        <span class="label" id="ctx-add-label">Add to playlist</span>
        <div class="scroll" role="group" aria-labelledby="ctx-add-label">
          <button
            v-for="pl in otherPlaylists"
            :key="pl.id"
            class="item"
            role="menuitemcheckbox"
            :aria-checked="store.isInPlaylist(pl.id, song.id)"
            @click="store.toggleSongInPlaylist(pl.id, song.id)"
          >
            <span class="check" :class="{ on: store.isInPlaylist(pl.id, song.id) }">
              <Icon v-if="store.isInPlaylist(pl.id, song.id)" name="check" :size="12" />
            </span>
            <span class="truncate">{{ pl.name }}</span>
          </button>
        </div>
        <button class="item" role="menuitem" @click="run(() => (state.createPlaylistOpen = true))">
          <Icon name="plus" :size="16" /> New playlist
        </button>

        <div class="divider" role="separator" />

        <button class="item" role="menuitem" @click="run(() => store.openSearch(song!.artist))">
          <Icon name="search" :size="16" /> <span class="truncate">More from {{ song.artist }}</span>
        </button>
        <button v-if="song.videoId" class="item" role="menuitem" @click="run(() => store.copyLink(song!))">
          <Icon name="link" :size="16" /> Copy YouTube link
        </button>
      </template>

      <template v-else-if="playlist">
        <div class="menu-head" aria-hidden="true">
          <Cover :src="playlist.cover" :hue="playlist.hue" :size="40" :radius="8" :icon="playlist.isDefault ? 'heart' : 'music'" />
          <span class="head-text">
            <span class="head-title truncate">{{ playlist.name }}</span>
            <span class="head-sub">{{ playlist.songIds.length }} songs</span>
          </span>
        </div>

        <button class="item" role="menuitem" :disabled="!playlist.songIds.length" @click="run(() => playPlaylist(false))">
          <Icon name="play" :size="16" /> Play
        </button>
        <button class="item" role="menuitem" :disabled="!playlist.songIds.length" @click="run(() => playPlaylist(true))">
          <Icon name="shuffle" :size="16" /> Shuffle play
        </button>
        <button
          class="item"
          role="menuitem"
          :disabled="!playlist.songIds.length"
          @click="run(() => store.addAllToQueue(store.playlistSongs(playlist!.id), playlist!.name))"
        >
          <Icon name="list-plus" :size="16" /> Add to queue
        </button>
        <button class="item" role="menuitem" @click="run(() => store.setView('playlist', playlist!.id))">
          <Icon name="chevron-right" :size="16" /> Open playlist
        </button>

        <template v-if="!playlist.isDefault && !store.isOwnerOf(playlist)">
          <div class="divider" role="separator" />
          <button class="item danger" role="menuitem" @click="run(() => store.leavePlaylist(playlist!.id))">
            <Icon name="x" :size="16" /> Leave playlist
          </button>
        </template>

        <template v-if="store.isOwnerOf(playlist)">
          <div class="divider" role="separator" />
          <button class="item" role="menuitem" @click="run(() => (state.inviteePlaylistId = playlist!.id))">
            <Icon name="user-plus" :size="16" /> Invite people
          </button>
          <button class="item" role="menuitem" @click="run(() => (state.editPlaylistId = playlist!.id))">
            <Icon name="edit-2" :size="16" /> Edit details
          </button>
          <div class="divider" role="separator" />
          <button class="item danger" role="menuitem" @click="run(() => store.requestDeletePlaylist(playlist!.id))">
            <Icon name="trash-2" :size="16" /> Delete playlist
          </button>
        </template>
      </template>
    </div>
  </Transition>
</template>

<style scoped>
.menu {
  position: fixed;
  z-index: 200;
  width: 26rem;
  max-height: calc(100vh - 16px);
  overflow-y: auto;
  padding: 0.6rem;
  border-radius: var(--r-lg);
  background: var(--panel-raised);
  border: 0.1rem solid var(--line-2);
  box-shadow: var(--shadow-pop);
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  transform-origin: top left;
}

.menu.from-end {
  transform-origin: top right;
}

.menu-head {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.6rem 0.6rem 1rem;
  margin-bottom: 0.4rem;
  border-bottom: 0.1rem solid var(--line);
}

.head-text {
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.head-title {
  font-size: 1.35rem;
  font-weight: 700;
  color: var(--text-h);
}

.head-sub {
  font-size: 1.2rem;
  color: var(--text-dim);
}

.item {
  display: flex;
  align-items: center;
  gap: 1.1rem;
  width: 100%;
  min-height: 3.6rem;
  padding: 0 1rem;
  border-radius: var(--r-sm);
  font-size: 1.35rem;
  font-weight: 600;
  color: var(--text);
  text-align: left;
  transition:
    background-color 0.12s var(--ease),
    color 0.12s var(--ease);
}

.item > svg {
  color: var(--text-faint);
  transition: color 0.12s var(--ease);
}

.item:hover:not(:disabled),
.item:focus-visible {
  background: var(--fill-3);
  color: var(--text-h);
  outline: none;
}

.item:hover:not(:disabled) > svg,
.item:focus-visible > svg {
  color: var(--accent);
}

.item > svg.liked {
  color: var(--like) !important;
}

.item.danger,
.item.danger > svg {
  color: var(--danger) !important;
}

.item.danger:hover,
.item.danger:focus-visible {
  background: var(--danger-soft);
}

.label {
  padding: 1rem 1rem 0.4rem;
  font-size: 1.05rem;
  font-weight: 750;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-faint);
}

.scroll {
  max-height: 16rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.check {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 1.8rem;
  height: 1.8rem;
  border-radius: 0.5rem;
  border: 0.15rem solid var(--fill-4);
  color: var(--on-accent);
  transition:
    background-color 0.12s var(--ease),
    border-color 0.12s var(--ease);
}

.check.on {
  background: var(--accent);
  border-color: var(--accent);
}

.divider {
  height: 0.1rem;
  margin: 0.5rem 0.4rem;
  background: var(--line);
}
</style>
