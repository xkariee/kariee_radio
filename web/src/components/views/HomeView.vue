<script setup lang="ts">
import { computed } from 'vue'
import type { Playlist, PlayingFrom, Song } from '../../types'
import { store } from '../../store'
import { moods } from '../../data/moods'
import { anchorFrom } from '../../utils/menu'
import Icon from '../Icon.vue'
import Cover from '../Cover.vue'

const { state } = store

const greeting = computed(() => {
  const h = new Date(state.now).getHours()
  if (h < 5) return 'Up late'
  if (h < 12) return 'Good morning'
  if (h < 18) return 'Good afternoon'
  return 'Good evening'
})

const blurb = computed(() => {
  switch (state.contextKind) {
    case 'radiocar':
      return 'You’re on the car radio. Everyone in the vehicle shares the controls.'
    case 'dj':
      return 'You’re at the DJ booth. The whole room hears this, so make it count.'
    default:
      return 'Your personal radio. Players around you hear what you play.'
  }
})

const recent = computed(() => store.recentlyPlayed.value.slice(0, 6))
const recentFrom: PlayingFrom = { label: 'Recently played', nav: { view: 'recent', playlistId: null } }

const playlists = computed(() =>
  [...state.playlists].sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0)),
)

const isCurrent = (song: Song) => store.currentSong.value?.id === song.id

function playTile(song: Song) {
  if (isCurrent(song)) store.togglePlay()
  else store.playSong(song, store.recentlyPlayed.value, recentFrom)
}

const playingFromPl = (pl: Playlist) => !!store.currentSong.value && state.playingFrom?.nav?.playlistId === pl.id

function playPlaylist(pl: Playlist) {
  if (playingFromPl(pl)) {
    store.togglePlay()
    return
  }
  store.playList(store.playlistSongs(pl.id), { label: pl.name, nav: { view: 'playlist', playlistId: pl.id } })
}

function plMeta(pl: Playlist) {
  const n = pl.songIds.length
  const songs = `${n} song${n === 1 ? '' : 's'}`
  if (pl.ownerIdentifier !== state.identifier) return `By ${pl.ownerName} · ${songs}`
  if (pl.collaborators.length) return `${pl.collaborators.length + 1} members · ${songs}`
  return songs
}
</script>

<template>
  <div class="home">
    <header class="hero">
      <p class="eyebrow">{{ greeting }}</p>
      <h1 class="view-title">
        {{ greeting === 'Up late' ? 'Still up' : 'Welcome back' }}, <span class="name">{{ state.myName }}</span>
      </h1>
      <p class="blurb">{{ blurb }}</p>

      <div class="moods" role="group" aria-label="Quick mood searches">
        <button
          v-for="m in moods.slice(0, 8)"
          :key="m.label"
          class="chip mood"
          :style="{ '--h': m.hue }"
          @click="store.openSearch(m.query)"
        >
          <span class="dot" aria-hidden="true" />
          {{ m.label }}
        </button>
      </div>
    </header>

    <section v-if="recent.length" class="block" aria-labelledby="jump-title">
      <div class="block-head">
        <h2 id="jump-title" class="section-title">Jump back in</h2>
        <button class="btn btn-quiet sm" @click="store.setView('recent')">
          Show all <Icon name="chevron-right" :size="14" />
        </button>
      </div>
      <ul class="tiles" role="list">
        <li v-for="song in recent" :key="song.id">
          <button
            class="tile"
            :class="{ current: isCurrent(song) }"
            :aria-label="`${isCurrent(song) && state.isPlaying ? 'Pause' : 'Play'} ${song.title} by ${song.artist}`"
            @click="playTile(song)"
            @contextmenu.prevent="store.openTrackMenu(song.id, anchorFrom($event))"
          >
            <Cover :src="song.thumbnail ?? null" :hue="song.hue" :size="64" :radius="0" />
            <span class="tile-text">
              <span class="tile-title truncate">{{ song.title }}</span>
              <span class="tile-sub truncate">{{ song.artist }}</span>
            </span>
            <span v-if="isCurrent(song)" class="eq" :class="{ live: state.isPlaying }" aria-hidden="true">
              <i /><i /><i /><i />
            </span>
            <span class="tile-play" aria-hidden="true">
              <Icon :name="isCurrent(song) && state.isPlaying ? 'pause' : 'play'" :size="16" />
            </span>
          </button>
        </li>
      </ul>
    </section>

    <section class="block" aria-labelledby="pl-title">
      <div class="block-head">
        <h2 id="pl-title" class="section-title">Your playlists</h2>
        <button class="btn btn-quiet sm" @click="state.createPlaylistOpen = true">
          <Icon name="plus" :size="14" /> New playlist
        </button>
      </div>
      <ul class="cards" role="list">
        <li v-for="pl in playlists" :key="pl.id" class="card" @contextmenu.prevent="store.openPlaylistMenu(pl.id, anchorFrom($event))">
          <button class="card-main" @click="store.setView('playlist', pl.id)">
            <span class="card-art" :class="{ liked: pl.isDefault }">
              <Cover :src="pl.cover" :hue="pl.hue" size="fill" :radius="12" :icon="pl.isDefault ? 'heart' : 'music'" />
            </span>
            <span class="card-name truncate">{{ pl.name }}</span>
            <span class="card-meta truncate">{{ plMeta(pl) }}</span>
          </button>
          <button
            class="card-play"
            :class="{ on: playingFromPl(pl) }"
            :disabled="!pl.songIds.length"
            :aria-label="`${playingFromPl(pl) && state.isPlaying ? 'Pause' : 'Play'} ${pl.name}`"
            @click="playPlaylist(pl)"
          >
            <Icon :name="playingFromPl(pl) && state.isPlaying ? 'pause' : 'play'" :size="18" />
          </button>
        </li>
        <li class="card">
          <button class="card-main new" @click="state.createPlaylistOpen = true">
            <span class="card-art new-art"><Icon name="plus" :size="30" /></span>
            <span class="card-name">Create playlist</span>
            <span class="card-meta">Collect songs, invite friends</span>
          </button>
        </li>
      </ul>
    </section>

    <section v-if="!recent.length" class="welcome">
      <span class="welcome-art" aria-hidden="true"><Icon name="headphones" :size="30" /></span>
      <div>
        <h2 class="section-title">Start your first session</h2>
        <p>Search any song or artist, or paste a YouTube link to play it straight away.</p>
      </div>
      <button class="btn btn-primary" @click="store.openSearch()"><Icon name="search" :size="15" /> Search music</button>
    </section>
  </div>
</template>

<style scoped>
.home {
  display: flex;
  flex-direction: column;
  gap: 3.2rem;
  padding-top: 1.4rem;
}

.hero {
  display: flex;
  flex-direction: column;
  gap: 0.8rem;
}

.hero .view-title {
  font-size: 3.6rem;
}

.name {
  background: linear-gradient(100deg, var(--accent-strong), var(--accent));
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.blurb {
  font-size: 1.45rem;
  color: var(--text-dim);
}

.moods {
  display: flex;
  flex-wrap: wrap;
  gap: 0.8rem;
  margin-top: 1.2rem;
}

.mood .dot {
  width: 0.8rem;
  height: 0.8rem;
  border-radius: 50%;
  background: hsl(var(--h), 85%, 66%);
  box-shadow: 0 0 0 0.3rem hsla(var(--h), 85%, 66%, 0.2);
}

.block-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.4rem;
}

.tiles {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(26rem, 1fr));
  gap: 1rem;
}

.tile {
  position: relative;
  display: flex;
  align-items: center;
  gap: 1.3rem;
  width: 100%;
  height: 6.4rem;
  padding-right: 1.2rem;
  border-radius: var(--r-md);
  background: var(--fill-2);
  overflow: hidden;
  text-align: left;
  transition:
    background-color 0.16s var(--ease),
    transform 0.16s var(--ease);
}

.tile:hover {
  background: var(--fill-3);
}

.tile:active {
  transform: scale(0.985);
}

.tile.current {
  background: var(--accent-soft);
  box-shadow: inset 0 0 0 0.1rem var(--accent-line);
}

.tile-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.tile-title {
  font-size: 1.4rem;
  font-weight: 700;
  color: var(--text-h);
}

.tile.current .tile-title {
  color: var(--accent);
}

.tile-sub {
  font-size: 1.2rem;
  color: var(--text-dim);
}

.tile-play {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3.4rem;
  height: 3.4rem;
  border-radius: 50%;
  background: var(--accent);
  color: var(--on-accent);
  box-shadow: 0 0.6rem 1.6rem -0.4rem var(--accent-glow);
  opacity: 0;
  transform: translateX(0.6rem) scale(0.9);
  transition:
    opacity 0.18s var(--ease),
    transform 0.22s var(--ease-out);
}

.tile:hover .tile-play,
.tile:focus-visible .tile-play {
  opacity: 1;
  transform: none;
}

.tile:hover .eq,
.tile:focus-visible .eq {
  display: none;
}

.cards {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(16.8rem, 1fr));
  gap: 1.2rem;
}

.card {
  position: relative;
}

.card-main {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  width: 100%;
  padding: 1.2rem 1.2rem 1.4rem;
  border-radius: var(--r-lg);
  background: var(--fill-1);
  text-align: left;
  transition: background-color 0.18s var(--ease);
}

.card-main:hover {
  background: var(--fill-2);
}

.card-art {
  display: block;
  margin-bottom: 0.9rem;
  border-radius: 1.2rem;
  box-shadow: 0 1.2rem 2.8rem -1.2rem rgba(0, 0, 0, 0.7);
}

.card-art.liked :deep(.cover) {
  background: linear-gradient(140deg, #ff6fa5, #7b3cff) !important;
}

.card-name {
  font-size: 1.45rem;
  font-weight: 700;
  color: var(--text-h);
}

.card-meta {
  font-size: 1.2rem;
  color: var(--text-dim);
}

.card-play {
  position: absolute;
  /* sits on the artwork's bottom-right corner: art bottom is ~6.7rem above the card bottom */
  right: 2rem;
  bottom: 7.6rem;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 4.6rem;
  height: 4.6rem;
  border-radius: 50%;
  background: var(--accent);
  color: var(--on-accent);
  box-shadow: 0 0.8rem 2rem -0.4rem rgba(0, 0, 0, 0.6);
  opacity: 0;
  transform: translateY(0.8rem);
  transition:
    opacity 0.2s var(--ease),
    transform 0.25s var(--ease-out),
    background-color 0.15s var(--ease);
}

.card:hover .card-play:not(:disabled),
.card:focus-within .card-play:not(:disabled),
.card-play.on {
  opacity: 1;
  transform: none;
}

.card-play:hover {
  background: var(--accent-strong);
  transform: scale(1.06) !important;
}

.card-play:disabled {
  display: none;
}

.card-main.new {
  height: 100%;
  border: 0.15rem dashed var(--line-2);
  background: transparent;
}

.card-main.new:hover {
  border-color: var(--accent-line);
  background: var(--accent-soft);
}

.new-art {
  display: flex;
  align-items: center;
  justify-content: center;
  aspect-ratio: 1;
  background: var(--fill-1);
  color: var(--text-dim);
  box-shadow: none;
}

.card-main.new:hover .new-art {
  color: var(--accent);
}

.welcome {
  display: flex;
  align-items: center;
  gap: 2rem;
  padding: 2.4rem;
  border-radius: var(--r-lg);
  background: linear-gradient(120deg, var(--accent-soft), var(--fill-1));
  border: 0.1rem solid var(--line);
}

.welcome > div {
  flex: 1;
}

.welcome p {
  margin-top: 0.4rem;
  color: var(--text-dim);
}

.welcome-art {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 6.4rem;
  height: 6.4rem;
  border-radius: 1.8rem;
  background: var(--accent);
  color: var(--on-accent);
}
</style>
