<script setup lang="ts">
import { computed, ref } from 'vue'
import type { PlayingFrom, Song } from '../../types'
import { store } from '../../store'
import { colorForId } from '../../utils/avatar'
import { anchorFrom } from '../../utils/menu'
import Icon from '../Icon.vue'
import Cover from '../Cover.vue'
import TrackRow from '../TrackRow.vue'
import Dropdown from '../Dropdown.vue'

const { state } = store

const isRecent = computed(() => state.view === 'recent')
const pl = store.activePlaylist
const missing = computed(() => !isRecent.value && !pl.value)

const songs = computed<Song[]>(() => (isRecent.value ? store.recentlyPlayed.value : store.activePlaylistSongs.value))

type SortKey = 'custom' | 'title' | 'artist' | 'duration'
const sort = ref<SortKey>('custom')
const sortOptions = computed<{ value: SortKey; label: string }[]>(() => [
  { value: 'custom', label: isRecent.value ? 'Most recent' : 'Custom order' },
  { value: 'title', label: 'Title' },
  { value: 'artist', label: 'Artist' },
  { value: 'duration', label: 'Duration' },
])
const find = ref('')

const shown = computed(() => {
  const q = find.value.trim().toLowerCase()
  let list = q
    ? songs.value.filter((s) => s.title.toLowerCase().includes(q) || s.artist.toLowerCase().includes(q))
    : songs.value
  if (sort.value === 'title') list = [...list].sort((a, b) => a.title.localeCompare(b.title))
  if (sort.value === 'artist') list = [...list].sort((a, b) => a.artist.localeCompare(b.artist))
  if (sort.value === 'duration') list = [...list].sort((a, b) => a.duration - b.duration)
  return list
})

const totalLength = computed(() => songs.value.reduce((sum, s) => sum + (s.duration || 0), 0))

const from = computed<PlayingFrom>(() =>
  isRecent.value || !pl.value
    ? { label: 'Recently played', nav: { view: 'recent', playlistId: null } }
    : { label: pl.value.name, nav: { view: 'playlist', playlistId: pl.value.id } },
)

const playingHere = computed(() => {
  if (!store.currentSong.value) return false
  const nav = state.playingFrom?.nav
  return !!nav && nav.view === from.value.nav?.view && nav.playlistId === from.value.nav?.playlistId
})

function playAll() {
  if (playingHere.value) store.togglePlay()
  else store.playList(shown.value, from.value)
}

const kind = computed(() => {
  if (isRecent.value) return 'History'
  if (pl.value?.isDefault) return 'Your favourites'
  if (pl.value && store.isShareable(pl.value)) return 'Collaborative playlist'
  return 'Playlist'
})

const title = computed(() => (isRecent.value ? 'Recently played' : pl.value?.name ?? ''))

const members = computed(() => {
  const p = pl.value
  if (!p || p.isDefault) return []
  return [{ identifier: p.ownerIdentifier, name: p.ownerName }, ...p.collaborators].map((c) => ({
    ...c,
    color: colorForId(c.identifier),
  }))
})

const heroStyle = computed(() => {
  if (pl.value?.isDefault) return { '--h1': '330', '--h2': '268' }
  if (isRecent.value) return {}
  const h = pl.value?.hue ?? 200
  return { '--h1': String(h), '--h2': String((h + 40) % 360) }
})

const canEdit = computed(() => !!pl.value && store.isOwnerOf(pl.value))
</script>

<template>
  <div v-if="missing" class="empty-state">
    <span class="badge"><Icon name="alert" :size="26" /></span>
    <h3>This playlist isn’t available</h3>
    <p>It may have been deleted, or you were removed from it.</p>
    <button class="btn btn-secondary" @click="store.setView('home')">Go home</button>
  </div>

  <div v-else class="collection" data-tracklist>
    <header class="hero" :class="{ recent: isRecent }" :style="heroStyle">
      <span class="hero-art" :class="{ liked: pl?.isDefault }">
        <Cover
          v-if="!isRecent"
          :src="pl?.cover ?? null"
          :hue="pl?.hue ?? 200"
          :size="184"
          :radius="16"
          :icon="pl?.isDefault ? 'heart' : 'music'"
        />
        <span v-else class="recent-art"><Icon name="history" :size="64" /></span>
      </span>
      <div class="hero-info">
        <span class="eyebrow">{{ kind }}</span>
        <h1 class="hero-title">{{ title }}</h1>
        <div class="hero-meta">
          <span v-if="members.length" class="avatars" aria-hidden="true">
            <span v-for="m in members.slice(0, 5)" :key="m.identifier" class="avatar" :style="{ background: m.color }">
              {{ m.name[0] }}
            </span>
          </span>
          <span v-if="pl && !pl.isDefault" class="owner">{{ pl.ownerName }}</span>
          <span v-if="members.length > 1" class="dotsep">{{ members.length }} members</span>
          <span class="dotsep">{{ songs.length }} song{{ songs.length === 1 ? '' : 's' }}</span>
          <span v-if="totalLength" class="dotsep">{{ store.formatLength(totalLength) }}</span>
        </div>
      </div>
    </header>

    <div class="action-bar">
      <button
        class="play-fab"
        :disabled="!shown.length"
        :aria-label="playingHere && state.isPlaying ? `Pause ${title}` : `Play ${title}`"
        @click="playAll"
      >
        <Icon :name="playingHere && state.isPlaying ? 'pause' : 'play'" :size="22" />
      </button>
      <button
        class="icon-btn lg"
        :aria-pressed="state.shuffle"
        :aria-label="state.shuffle ? 'Shuffle on' : 'Shuffle off'"
        :title="state.shuffle ? 'Shuffle on' : 'Shuffle off'"
        @click="store.toggleShuffle()"
      >
        <Icon name="shuffle" :size="22" />
      </button>
      <button
        class="icon-btn lg"
        :disabled="!shown.length"
        aria-label="Add all to queue"
        title="Add all to queue"
        @click="store.addAllToQueue(shown, title)"
      >
        <Icon name="list-plus" :size="22" />
      </button>
      <template v-if="canEdit && pl">
        <button class="btn btn-secondary sm" @click="state.inviteePlaylistId = pl.id">
          <Icon name="user-plus" :size="15" /> Invite
        </button>
        <button class="icon-btn lg" aria-label="Edit details" title="Edit details" @click="state.editPlaylistId = pl.id">
          <Icon name="edit-2" :size="19" />
        </button>
      </template>
      <button
        v-if="pl && !pl.isDefault"
        class="icon-btn lg"
        :aria-label="`More options for ${pl.name}`"
        title="More options"
        @click="store.openPlaylistMenu(pl.id, anchorFrom($event))"
      >
        <Icon name="more-horizontal" :size="22" />
      </button>

      <div class="spacer" />

      <div v-if="songs.length > 1" class="find">
        <Icon name="search" :size="15" />
        <input v-model="find" type="text" :aria-label="`Find in ${title}`" placeholder="Find in list" @keydown.esc.stop.prevent="find = ''" />
      </div>
      <Dropdown v-if="songs.length > 1" v-model="sort" label="Sort by" icon="sort" align="end" :options="sortOptions" />
    </div>

    <div v-if="shown.length" class="list-head" aria-hidden="true">
      <span>#</span>
      <span />
      <span>Title</span>
      <span />
      <span class="right"><Icon name="clock" :size="15" /></span>
      <span />
    </div>

    <div v-if="shown.length" class="tracks" role="list" :aria-label="`${title} songs`">
      <TrackRow
        v-for="(song, i) in shown"
        :key="song.id"
        role="listitem"
        :song="song"
        :index="i"
        :context="shown"
        :from="from"
        :context-playlist-id="isRecent ? undefined : pl?.id"
      />
    </div>

    <div v-else-if="find" class="empty-state">
      <h3>No matches</h3>
      <p>Nothing in this list matches “{{ find }}”.</p>
      <button class="btn btn-secondary sm" @click="find = ''">Clear filter</button>
    </div>

    <div v-else class="empty-state">
      <span class="badge"><Icon :name="isRecent ? 'history' : pl?.isDefault ? 'heart' : 'music'" :size="26" /></span>
      <h3 v-if="isRecent">Nothing played yet</h3>
      <h3 v-else-if="pl?.isDefault">Songs you like will live here</h3>
      <h3 v-else>Let’s fill this playlist</h3>
      <p v-if="isRecent">Your listening history shows up here, so you can jump back in any time.</p>
      <p v-else-if="pl?.isDefault">Tap the heart on any song, or press <kbd>L</kbd> while it plays.</p>
      <p v-else>Find songs with search, then use “Add to playlist” from a song’s menu.</p>
      <button class="btn btn-primary" @click="store.openSearch()"><Icon name="search" :size="15" /> Find songs</button>
    </div>
  </div>
</template>

<style scoped>
.collection {
  display: flex;
  flex-direction: column;
  padding-top: 0.8rem;
}

.hero {
  position: relative;
  display: flex;
  align-items: flex-end;
  gap: 2.6rem;
  padding: 2.6rem;
  border-radius: var(--r-xl);
  overflow: hidden;
  background:
    radial-gradient(60rem 30rem at 0% 0%, hsla(var(--h1), 70%, 45%, 0.5), transparent 70%),
    radial-gradient(50rem 30rem at 100% 100%, hsla(var(--h2), 70%, 40%, 0.35), transparent 70%),
    var(--fill-1);
  border: 0.1rem solid var(--line);
}

.hero.recent {
  background:
    radial-gradient(60rem 30rem at 0% 0%, var(--accent-deep), transparent 70%),
    radial-gradient(50rem 30rem at 100% 100%, var(--accent-soft), transparent 70%),
    var(--fill-1);
}

.hero-art {
  flex-shrink: 0;
  border-radius: 1.6rem;
  box-shadow: 0 2.4rem 5rem -1.6rem rgba(0, 0, 0, 0.75);
}

.hero-art.liked :deep(.cover) {
  background: linear-gradient(140deg, #ff6fa5, #7b3cff) !important;
}

.recent-art {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 18.4rem;
  height: 18.4rem;
  border-radius: 1.6rem;
  background: linear-gradient(145deg, var(--accent), var(--accent-deep));
  color: var(--on-accent);
}

.hero-info {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.8rem;
}

.hero-info .eyebrow {
  color: var(--text-dim);
}

.hero-title {
  font-size: clamp(3rem, 4.4vw, 5.6rem);
  font-weight: 800;
  letter-spacing: -0.035em;
  line-height: 1.02;
  color: var(--text-h);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  padding-bottom: 0.2rem;
}

.hero-meta {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.8rem;
  font-size: 1.35rem;
  color: var(--text-dim);
}

.owner {
  font-weight: 700;
  color: var(--text-h);
}

.dotsep::before {
  content: '•';
  margin-right: 0.8rem;
  color: var(--text-faint);
}

.hero-meta > .dotsep:first-child::before {
  display: none;
}

.avatars {
  display: flex;
}

.avatar {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.6rem;
  height: 2.6rem;
  margin-left: -0.8rem;
  border-radius: 50%;
  border: 0.2rem solid var(--panel-solid);
  font-size: 1.1rem;
  font-weight: 800;
  color: rgba(0, 0, 0, 0.62);
}

.avatar:first-child {
  margin-left: 0;
}

.action-bar {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  padding: 2rem 0.4rem 1.6rem;
}

.spacer {
  flex: 1;
}

.find {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  height: 3.4rem;
  width: 20rem;
  padding: 0 1.2rem;
  border-radius: var(--r-pill);
  background: var(--fill-2);
  border: 0.1rem solid var(--line);
  color: var(--text-faint);
  transition: border-color 0.16s var(--ease);
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

.list-head {
  display: grid;
  grid-template-columns: 3rem 4.4rem minmax(0, 1fr) auto 5rem 3rem;
  gap: 1.2rem;
  padding: 0 1rem 0.8rem;
  margin-bottom: 0.6rem;
  border-bottom: 0.1rem solid var(--line);
  font-size: 1.15rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--text-faint);
}

.list-head span:first-child {
  text-align: center;
}

.list-head .right {
  display: flex;
  justify-content: flex-end;
}

.tracks {
  display: flex;
  flex-direction: column;
  gap: var(--row-gap);
}
</style>
