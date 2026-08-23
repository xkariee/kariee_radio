<script setup lang="ts">
import { computed } from 'vue'
import { store } from '../store'
import Icon from './Icon.vue'
import Cover from './Cover.vue'
import TrackRow from './TrackRow.vue'
import QueueView from './QueueView.vue'
import SearchResultsView from './SearchResultsView.vue'

const isSearching = computed(() => store.state.searchQuery.trim().length > 0)

const tracks = computed(() =>
  store.state.view === 'playlist' ? store.activePlaylistSongs.value : store.recentlyPlayed.value,
)

const collaborators = computed(() => {
  const pl = store.activePlaylist.value
  if (!pl) return []
  return [pl.ownerId, ...pl.collaboratorIds]
    .map((id) => store.state.users.find((u) => u.id === id))
    .filter((u): u is NonNullable<typeof u> => !!u)
})

function playAll() {
  if (tracks.value.length) store.playSong(tracks.value[0], tracks.value)
}
</script>

<template>
  <main class="content">
    <SearchResultsView v-if="isSearching" />
    <QueueView v-else-if="store.state.view === 'queue'" />

    <div v-else class="view">
      <div v-if="store.state.view === 'playlist' && store.activePlaylist.value" class="playlist-header">
        <Cover
          :src="store.activePlaylist.value.cover"
          :hue="store.activePlaylist.value.hue"
          :size="112"
          :radius="12"
          :icon="store.activePlaylist.value.isDefault ? 'heart' : 'disc'"
        />
        <div class="playlist-info">
          <span class="kicker">{{ store.activePlaylist.value.isDefault ? 'Default Playlist' : 'Playlist' }}</span>
          <h1>{{ store.activePlaylist.value.name }}</h1>
          <div class="playlist-sub">
            <span>{{ tracks.length }} song{{ tracks.length === 1 ? '' : 's' }}</span>
            <div class="collab-stack" v-if="collaborators.length">
              <span
                v-for="c in collaborators"
                :key="c.id"
                class="collab-dot"
                :style="{ background: c.color }"
                :title="c.name"
              >{{ c.name[0] }}</span>
            </div>
          </div>
          <div class="playlist-actions">
            <button class="btn-primary" @click="playAll" :disabled="!tracks.length">
              <Icon name="play" :size="14" />
              Play
            </button>
            <template v-if="!store.activePlaylist.value.isDefault">
              <button class="btn-secondary" @click="store.state.inviteePlaylistId = store.activePlaylist.value!.id">
                <Icon name="user-plus" :size="14" />
                Invite
              </button>
              <button class="btn-secondary" @click="store.state.editPlaylistId = store.activePlaylist.value!.id">
                <Icon name="edit-2" :size="14" />
                Edit
              </button>
            </template>
          </div>
        </div>
      </div>

      <div v-else class="library-header">
        <h1>Recently Played</h1>
        <button class="btn-primary" @click="playAll" :disabled="!tracks.length">
          <Icon name="play" :size="14" />
          Play All
        </button>
      </div>

      <div class="track-list">
        <TrackRow
          v-for="(song, i) in tracks"
          :key="song.id"
          :song="song"
          :index="i"
          :context="tracks"
          :context-playlist-id="store.state.view === 'playlist' ? store.state.activePlaylistId ?? undefined : undefined"
        />
        <div v-if="!tracks.length" class="empty">
          <span class="empty-badge">
            <Icon :name="store.state.view === 'playlist' ? 'music' : 'clock'" :size="24" />
          </span>
          <p v-if="store.state.view === 'playlist'">This playlist is empty. Search for songs to add some.</p>
          <p v-else>Nothing played yet. Search above to find something to play.</p>
        </div>
      </div>
    </div>
  </main>
</template>

<style scoped>
.content {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  overflow-y: auto;
  padding: 20px 22px 12px;
}

.view {
  display: flex;
  flex-direction: column;
}

.library-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
}

.library-header h1 {
  font-size: 19px;
  font-weight: 600;
  color: var(--text-h);
  margin: 0;
}

.playlist-header {
  display: flex;
  gap: 20px;
  margin-bottom: 18px;
  padding-bottom: 18px;
  border-bottom: 1px solid var(--line);
}

.playlist-info {
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  gap: 6px;
  min-width: 0;
}

.kicker {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--teal);
}

.playlist-info h1 {
  font-size: 26px;
  font-weight: 700;
  color: var(--text-h);
  margin: 0;
  line-height: 1.15;
}

.playlist-sub {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 12.5px;
  color: var(--text-faint);
}

.collab-stack {
  display: flex;
}

.collab-dot {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 10px;
  font-weight: 700;
  color: rgba(0, 0, 0, 0.55);
  border: 2px solid var(--surface-1);
  margin-left: -6px;
  transition: transform 0.12s var(--ease);
}

.collab-dot:hover {
  transform: translateY(-2px) scale(1.08);
}

.collab-stack .collab-dot:first-child {
  margin-left: 0;
}

.playlist-actions {
  display: flex;
  gap: 8px;
  margin-top: 4px;
}

.track-list {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding-bottom: 12px;
}

.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  color: var(--text-faint);
  padding: 48px 0;
  font-size: 13px;
  text-align: center;
}

.empty-badge {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: var(--surface-2);
  border: 1px solid var(--line);
  color: var(--text-faint);
}
</style>
