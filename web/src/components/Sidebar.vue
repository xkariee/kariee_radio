<script setup lang="ts">
import { computed } from 'vue'
import { store } from '../store'
import Icon from './Icon.vue'
import Cover from './Cover.vue'

const sortedPlaylists = computed(() =>
  [...store.state.playlists].sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0)),
)

function openPlaylistMenu(e: MouseEvent, playlistId: string | number) {
  e.stopPropagation()
  const rect = (e.currentTarget as HTMLElement).getBoundingClientRect()
  store.openPlaylistMenu(playlistId, rect.right, rect.top)
}
</script>

<template>
  <aside class="sidebar">
    <nav class="nav-group">
      <button
        class="nav-item"
        :class="{ active: store.state.view === 'recent' }"
        @click="store.setView('recent')"
      >
        <Icon name="clock" :size="16" />
        <span>Recently Played</span>
      </button>
      <button
        class="nav-item"
        :class="{ active: store.state.view === 'queue' }"
        @click="store.setView('queue')"
      >
        <Icon name="list-music" :size="16" />
        <span>Queue</span>
        <span v-if="store.upNext.value.length" class="count">{{ store.upNext.value.length }}</span>
      </button>
    </nav>

    <div class="invites-head" v-if="store.state.invites.length">
      <span>Invited</span>
    </div>
    <div class="invite-list" v-if="store.state.invites.length">
      <div class="invite-row" v-for="inv in store.state.invites" :key="inv.playlistId">
        <Cover :src="null" :hue="inv.hue" :size="30" :radius="6" icon="disc" />
        <div class="invite-meta">
          <span class="invite-name">{{ inv.name }}</span>
          <span class="invite-sub">from {{ inv.invitedByName }}</span>
        </div>
        <div class="invite-actions">
          <button class="btn-icon ghost" title="Accept" @click="store.acceptInvite(inv.playlistId)">
            <Icon name="check" :size="13" />
          </button>
          <button class="btn-icon ghost" title="Decline" @click="store.declineInvite(inv.playlistId)">
            <Icon name="x" :size="13" />
          </button>
        </div>
      </div>
    </div>

    <div class="playlists-head">
      <span>Your Playlists</span>
      <button class="btn-icon ghost" title="Create playlist" @click="store.state.createPlaylistOpen = true">
        <Icon name="plus" :size="15" />
      </button>
    </div>

    <div class="playlist-list">
      <button
        v-for="pl in sortedPlaylists"
        :key="pl.id"
        class="playlist-row"
        :class="{ active: store.state.view === 'playlist' && store.state.activePlaylistId === pl.id }"
        @click="store.setView('playlist', pl.id)"
      >
        <Cover
          :src="pl.cover"
          :hue="pl.hue"
          :size="34"
          :radius="6"
          :icon="pl.isDefault ? 'heart' : 'disc'"
        />
        <span class="playlist-name">{{ pl.name }}</span>
        <span class="row-end">
          <span class="playlist-count">{{ pl.songIds.length }}</span>
          <span class="row-menu-btn" @click="openPlaylistMenu($event, pl.id)">
            <Icon name="more-vertical" :size="15" />
          </span>
        </span>
      </button>
    </div>
  </aside>
</template>

<style scoped>
.sidebar {
  width: 236px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  border-right: 1px solid var(--line);
  padding: 14px 10px 10px;
  min-height: 0;
}

.nav-group {
  display: flex;
  flex-direction: column;
  gap: 2px;
  margin-bottom: 16px;
}

.nav-item {
  position: relative;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 10px;
  border-radius: var(--radius-sm);
  color: var(--text-faint);
  font-size: 13.5px;
  font-weight: 500;
  text-align: left;
  transition:
    background-color 0.15s var(--ease),
    color 0.15s var(--ease);
}

.nav-item::before {
  content: '';
  position: absolute;
  left: -10px;
  top: 50%;
  width: 3px;
  height: 16px;
  border-radius: 0 3px 3px 0;
  background: var(--teal);
  transform: translateY(-50%) scaleY(0);
  transition: transform 0.15s var(--ease);
}

.nav-item:hover {
  background: var(--surface-2);
  color: var(--text);
}

.nav-item.active {
  background: var(--teal-wash);
  color: var(--teal);
}

.nav-item.active::before {
  transform: translateY(-50%) scaleY(1);
}

.nav-item .count {
  margin-left: auto;
  font-size: 11px;
  color: var(--text-faint);
}

.nav-item.active .count {
  color: var(--teal);
}

.invites-head {
  padding: 0 10px;
  margin-bottom: 6px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: var(--teal);
}

.invite-list {
  display: flex;
  flex-direction: column;
  gap: 1px;
  margin-bottom: 14px;
}

.invite-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 8px;
  border-radius: var(--radius-sm);
}

.invite-row:hover {
  background: var(--surface-2);
}

.invite-meta {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.invite-name {
  font-size: 12.5px;
  font-weight: 500;
  color: var(--text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.invite-sub {
  font-size: 11px;
  color: var(--text-faint);
}

.invite-actions {
  display: flex;
  gap: 2px;
  flex-shrink: 0;
}

.playlists-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 10px;
  margin-bottom: 8px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: var(--text-faint);
}

.playlists-head .btn-icon:hover {
  color: var(--teal);
  transform: rotate(90deg);
}

.playlist-list {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.playlist-row {
  position: relative;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 8px;
  border-radius: var(--radius-sm);
  text-align: left;
  transition: background-color 0.15s var(--ease);
}

.playlist-row::before {
  content: '';
  position: absolute;
  left: -10px;
  top: 50%;
  width: 3px;
  height: 16px;
  border-radius: 0 3px 3px 0;
  background: var(--teal);
  transform: translateY(-50%) scaleY(0);
  transition: transform 0.15s var(--ease);
}

.playlist-row:hover {
  background: var(--surface-2);
}

.playlist-row.active {
  background: var(--surface-2);
}

.playlist-row.active::before {
  transform: translateY(-50%) scaleY(1);
}

.playlist-row.active .playlist-name {
  color: var(--teal);
}

.playlist-name {
  flex: 1;
  min-width: 0;
  font-size: 13px;
  font-weight: 500;
  color: var(--text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  transition: color 0.15s var(--ease);
}

.row-end {
  display: grid;
  flex-shrink: 0;
  place-items: center;
}

.row-end > * {
  grid-area: 1 / 1;
}

.playlist-count {
  font-size: 11px;
  color: var(--text-faint);
  transition: opacity 0.1s var(--ease);
}

.row-menu-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border-radius: 6px;
  color: var(--text-faint);
  opacity: 0;
  transform: scale(0.85);
  transition:
    opacity 0.12s var(--ease),
    transform 0.12s var(--ease),
    background-color 0.12s var(--ease),
    color 0.12s var(--ease);
}

.row-menu-btn:hover {
  background: var(--surface-4);
  color: var(--text);
}

.playlist-row:hover .row-menu-btn {
  opacity: 1;
  transform: scale(1);
}

.playlist-row:hover .playlist-count {
  opacity: 0;
}
</style>
