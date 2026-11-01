<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import type { Playlist, ViewKind } from '../types'
import { store } from '../store'
import { anchorFrom } from '../utils/menu'
import Icon from './Icon.vue'
import Cover from './Cover.vue'

const { state } = store

const navItems = computed<{ view: ViewKind; label: string; icon: string }[]>(() => [
  { view: 'home', label: 'Home', icon: 'home' },
  { view: 'search', label: 'Search', icon: 'search' },
  { view: 'queue', label: 'Queue', icon: 'list-music' },
  { view: 'recent', label: 'Recently played', icon: 'history' },
  ...(state.isAdmin ? [{ view: 'admin' as ViewKind, label: 'Admin', icon: 'shield' }] : []),
])

// Every client already receives every broadcast, so the admin badge needs no extra request.
const liveCount = computed(() => Object.values(state.live).filter((b) => b.playing).length)

function go(view: ViewKind) {
  if (view === 'search') store.openSearch()
  else store.setView(view)
}

const filters = [
  { id: 'all', label: 'All' },
  { id: 'mine', label: 'Mine' },
  { id: 'shared', label: 'Shared' },
] as const

const findOpen = ref(false)
const findQuery = ref('')
const findInput = ref<HTMLInputElement | null>(null)

async function toggleFind() {
  findOpen.value = !findOpen.value
  if (!findOpen.value) findQuery.value = ''
  else {
    await nextTick()
    findInput.value?.focus()
  }
}

function onFindEsc() {
  if (findQuery.value) findQuery.value = ''
  else findOpen.value = false
}

const playlists = computed(() => {
  let list = [...state.playlists].sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0))
  if (state.libraryFilter === 'mine') list = list.filter((p) => p.ownerIdentifier === state.identifier)
  if (state.libraryFilter === 'shared') list = list.filter(store.isShareable)
  const q = findQuery.value.trim().toLowerCase()
  if (q) list = list.filter((p) => p.name.toLowerCase().includes(q))
  return list
})

function subtitle(pl: Playlist) {
  const count = `${pl.songIds.length} song${pl.songIds.length === 1 ? '' : 's'}`
  if (pl.isDefault) return `Playlist · ${count}`
  if (pl.ownerIdentifier !== state.identifier) return `By ${pl.ownerName} · ${count}`
  if (pl.collaborators.length) return `Shared · ${count}`
  return `Playlist · ${count}`
}

const isActive = (pl: Playlist) => state.view === 'playlist' && state.activePlaylistId === pl.id
const isPlayingFrom = (pl: Playlist) => !!store.currentSong.value && state.playingFrom?.nav?.playlistId === pl.id

function openMenu(e: MouseEvent, pl: Playlist) {
  store.openPlaylistMenu(pl.id, anchorFrom(e))
}
</script>

<template>
  <nav class="panel sidebar" aria-label="Navigation and library">
    <div class="brand">
      <span class="logo" aria-hidden="true">
        <Icon name="radio" :size="18" />
      </span>
      <span class="wordmark">AX <b>Radio</b></span>
    </div>

    <ul class="nav" role="list">
      <li v-for="item in navItems" :key="item.view">
        <button
          class="nav-item"
          :class="{ active: state.view === item.view }"
          :aria-current="state.view === item.view ? 'page' : undefined"
          @click="go(item.view)"
        >
          <Icon :name="item.icon" :size="19" />
          <span>{{ item.label }}</span>
          <span v-if="item.view === 'queue' && store.upNext.value.length" class="count">
            {{ store.upNext.value.length }}<span class="sr-only"> songs queued</span>
          </span>
          <span v-if="item.view === 'admin' && liveCount" class="count live" :title="`${liveCount} radios playing on the server`">
            <i aria-hidden="true" />{{ liveCount }}<span class="sr-only"> radios playing</span>
          </span>
        </button>
      </li>
    </ul>

    <div class="library">
      <div class="lib-head">
        <h2 class="lib-title"><Icon name="library" :size="18" /> Your Library</h2>
        <button
          class="icon-btn sm"
          :aria-pressed="findOpen"
          aria-label="Find in library"
          title="Find in library"
          @click="toggleFind"
        >
          <Icon name="search" :size="15" />
        </button>
        <button class="icon-btn sm" aria-label="Create playlist" title="Create playlist" @click="state.createPlaylistOpen = true">
          <Icon name="plus" :size="17" />
        </button>
      </div>

      <div class="filters" role="group" aria-label="Filter playlists">
        <button
          v-for="f in filters"
          :key="f.id"
          class="chip sm"
          :aria-pressed="state.libraryFilter === f.id"
          @click="state.libraryFilter = f.id"
        >
          {{ f.label }}
        </button>
      </div>

      <Transition name="fade">
        <div v-if="findOpen" class="find">
          <Icon name="search" :size="14" />
          <input
            ref="findInput"
            v-model="findQuery"
            type="text"
            placeholder="Find a playlist"
            aria-label="Find a playlist"
            @keydown.esc.stop.prevent="onFindEsc"
          />
        </div>
      </Transition>

      <div class="lib-scroll">
        <section v-if="state.invites.length" class="invites" aria-label="Playlist invites">
          <article v-for="inv in state.invites" :key="inv.playlistId" class="invite">
            <div class="invite-top">
              <Cover :hue="inv.hue" :size="36" :radius="8" icon="users" />
              <div class="invite-meta">
                <span class="invite-kicker"><Icon name="inbox" :size="12" /> Invite</span>
                <span class="invite-name truncate">{{ inv.name }}</span>
                <span class="invite-from truncate">from {{ inv.invitedByName }}</span>
              </div>
            </div>
            <div class="invite-actions">
              <button class="btn btn-primary sm" @click="store.acceptInvite(inv.playlistId)">Join</button>
              <button class="btn btn-quiet sm" @click="store.declineInvite(inv.playlistId)">Decline</button>
            </div>
          </article>
        </section>

        <ul class="pl-list" role="list" aria-label="Playlists">
          <li
            v-for="pl in playlists"
            :key="pl.id"
            class="pl-row"
            :class="{ active: isActive(pl) }"
            @contextmenu.prevent="openMenu($event, pl)"
          >
            <button
              class="pl-main"
              :aria-current="isActive(pl) ? 'page' : undefined"
              @click="store.setView('playlist', pl.id)"
            >
              <span class="pl-cover" :class="{ liked: pl.isDefault }">
                <Cover :src="pl.cover" :hue="pl.hue" :size="44" :radius="10" :icon="pl.isDefault ? 'heart' : 'music'" />
              </span>
              <span class="pl-text">
                <span class="pl-name truncate">{{ pl.name }}</span>
                <span class="pl-sub truncate">{{ subtitle(pl) }}</span>
              </span>
              <span v-if="isPlayingFrom(pl)" class="eq" :class="{ live: state.isPlaying }" aria-label="Now playing">
                <i /><i /><i />
              </span>
            </button>
            <button class="icon-btn sm pl-more" :aria-label="`More options for ${pl.name}`" @click="openMenu($event, pl)">
              <Icon name="more-horizontal" :size="16" />
            </button>
          </li>
        </ul>

        <p v-if="!playlists.length" class="lib-empty">
          {{ findQuery ? `No playlists match “${findQuery}”.` : 'Nothing here yet.' }}
        </p>
      </div>
    </div>

    <button class="btn btn-secondary new-pl" @click="state.createPlaylistOpen = true">
      <Icon name="plus" :size="16" />
      New playlist
    </button>
  </nav>
</template>

<style scoped>
.sidebar {
  display: flex;
  flex-direction: column;
  padding: 1.8rem 1.2rem 1.4rem;
}

.brand {
  display: flex;
  align-items: center;
  gap: 1.1rem;
  padding: 0 0.8rem 1.8rem;
}

.logo {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3.6rem;
  height: 3.6rem;
  border-radius: 1.1rem;
  background: linear-gradient(145deg, var(--accent-strong), var(--accent));
  color: var(--on-accent);
  box-shadow: 0 0.8rem 2rem -0.6rem var(--accent-glow);
}

.wordmark {
  font-size: 1.75rem;
  font-weight: 650;
  letter-spacing: -0.02em;
  color: var(--text-h);
}

.wordmark b {
  font-weight: 800;
  color: var(--accent);
}

.nav {
  list-style: none;
  margin: 0;
  padding: 0 0 1.4rem;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  border-bottom: 0.1rem solid var(--line);
}

.nav-item {
  position: relative;
  display: flex;
  align-items: center;
  gap: 1.3rem;
  width: 100%;
  height: 4.2rem;
  padding: 0 1.2rem;
  border-radius: var(--r-md);
  color: var(--text-dim);
  font-size: 1.45rem;
  font-weight: 650;
  transition:
    background-color 0.16s var(--ease),
    color 0.16s var(--ease);
}

.nav-item:hover {
  color: var(--text-h);
  background: var(--fill-1);
}

.nav-item.active {
  color: var(--text-h);
  background: var(--fill-2);
}

.nav-item.active svg {
  color: var(--accent);
}

.nav-item::before {
  content: '';
  position: absolute;
  left: -1.2rem;
  top: 50%;
  width: 0.4rem;
  height: 2rem;
  margin-top: -1rem;
  border-radius: 0 0.4rem 0.4rem 0;
  background: var(--accent);
  transform: scaleY(0);
  transition: transform 0.2s var(--ease-spring);
}

.nav-item.active::before {
  transform: scaleY(1);
}

.count {
  margin-left: auto;
  min-width: 2.2rem;
  height: 2.2rem;
  padding: 0 0.7rem;
  border-radius: var(--r-pill);
  background: var(--accent-soft);
  color: var(--accent);
  font-size: 1.15rem;
  font-weight: 750;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.count.live {
  gap: 0.5rem;
  background: rgba(98, 227, 166, 0.12);
  color: var(--ok);
}

.count.live i {
  width: 0.6rem;
  height: 0.6rem;
  border-radius: 50%;
  background: currentColor;
}

.library {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  padding-top: 1.4rem;
}

.lib-head {
  display: flex;
  align-items: center;
  gap: 0.2rem;
  padding: 0 0.4rem 0 1.2rem;
}

.lib-title {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 1rem;
  font-size: 1.45rem;
  font-weight: 700;
  color: var(--text-dim);
}

.filters {
  display: flex;
  gap: 0.6rem;
  padding: 1rem 0.8rem 0.4rem;
}

.chip.sm {
  height: 2.8rem;
  padding: 0 1.2rem;
  font-size: 1.2rem;
}

.find {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  margin: 0.8rem 0.8rem 0;
  padding: 0 1.1rem;
  height: 3.4rem;
  border-radius: var(--r-sm);
  background: var(--fill-2);
  color: var(--text-faint);
  border: 0.1rem solid var(--line);
}

.find:focus-within {
  border-color: var(--accent-line);
}

.find input {
  flex: 1;
  min-width: 0;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-h);
  font-size: 1.3rem;
}

.find input::placeholder {
  color: var(--text-faint);
}

.lib-scroll {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
  margin: 0.8rem -0.4rem 0;
  padding: 0 0.4rem;
}

.invites {
  display: flex;
  flex-direction: column;
  gap: 0.8rem;
  margin-bottom: 1rem;
}

.invite {
  padding: 1.1rem;
  border-radius: var(--r-lg);
  background: linear-gradient(150deg, var(--accent-soft), var(--fill-1));
  border: 0.1rem solid var(--accent-line);
}

.invite-top {
  display: flex;
  gap: 1rem;
  align-items: center;
}

.invite-meta {
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.invite-kicker {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 1.05rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--accent);
}

.invite-name {
  font-size: 1.35rem;
  font-weight: 700;
  color: var(--text-h);
}

.invite-from {
  font-size: 1.2rem;
  color: var(--text-dim);
}

.invite-actions {
  display: flex;
  gap: 0.6rem;
  margin-top: 1rem;
}

.invite-actions .btn {
  flex: 1;
}

.pl-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.pl-row {
  position: relative;
  border-radius: var(--r-md);
  transition: background-color 0.16s var(--ease);
}

.pl-row:hover {
  background: var(--fill-1);
}

.pl-row.active {
  background: var(--fill-2);
}

.pl-main {
  display: flex;
  align-items: center;
  gap: 1.1rem;
  width: 100%;
  padding: 0.6rem 0.8rem;
  border-radius: var(--r-md);
  text-align: left;
}

.pl-cover {
  border-radius: 1rem;
  transition: transform 0.2s var(--ease);
}

.pl-cover.liked :deep(.cover) {
  background: linear-gradient(140deg, #ff6fa5, #7b3cff) !important;
}

.pl-row:hover .pl-cover {
  transform: scale(1.04);
}

.pl-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.pl-name {
  font-size: 1.4rem;
  font-weight: 650;
  color: var(--text-h);
}

.pl-row.active .pl-name {
  color: var(--accent);
}

.pl-sub {
  font-size: 1.2rem;
  color: var(--text-faint);
}

.pl-main .eq {
  margin-right: 0.4rem;
}

.pl-more {
  position: absolute;
  right: 0.6rem;
  top: 50%;
  margin-top: -1.5rem;
  opacity: 0;
  background: var(--panel-raised);
  transition:
    opacity 0.14s var(--ease),
    background-color 0.14s var(--ease);
}

.pl-row:hover .pl-more,
.pl-row:focus-within .pl-more {
  opacity: 1;
}

.pl-row:hover .eq,
.pl-row:focus-within .eq {
  visibility: hidden;
}

.lib-empty {
  padding: 2rem 1.2rem;
  font-size: 1.3rem;
  color: var(--text-faint);
  text-align: center;
}

.new-pl {
  margin-top: 1.2rem;
  width: 100%;
  height: 4.4rem;
}
</style>
