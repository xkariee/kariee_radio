<script setup lang="ts">
import { computed } from 'vue'
import type { PlayingFrom } from '../../types'
import { store } from '../../store'
import { formatTime } from '../../utils/format'
import { anchorFrom } from '../../utils/menu'
import { moods } from '../../data/moods'
import Icon from '../Icon.vue'
import Cover from '../Cover.vue'
import TrackRow from '../TrackRow.vue'

const { state } = store

const q = computed(() => state.searchQuery.trim())
const browsing = computed(() => q.value.length < 2)

const results = store.searchResults
const top = computed(() => results.value[0])
const topSongs = computed(() => results.value.slice(1, 5))
const more = computed(() => results.value.slice(5))

const from = computed<PlayingFrom>(() => ({ label: `Search: “${q.value}”`, nav: { view: 'search', playlistId: null } }))

const topIsCurrent = computed(() => !!top.value && store.currentSong.value?.id === top.value.id)

function playTop() {
  if (!top.value) return
  if (topIsCurrent.value) store.togglePlay()
  else store.playSong(top.value, results.value, from.value)
}
</script>

<template>
  <div class="search-view" data-tracklist>
    <div v-if="!store.youtubeConfigured" class="notice warn" role="alert">
      <Icon name="alert" :size="20" />
      <div>
        <strong>Search is unavailable right now.</strong>
        <span>Ask a server admin to set up music search. Your playlists still work.</span>
      </div>
    </div>

    <template v-if="browsing">
      <section v-if="state.recentSearches.length" class="block" aria-labelledby="recent-searches">
        <div class="block-head">
          <h2 id="recent-searches" class="section-title">Recent searches</h2>
          <button class="btn btn-quiet sm" @click="store.forgetSearch()">Clear all</button>
        </div>
        <ul class="recent" role="list">
          <li v-for="term in state.recentSearches" :key="term" class="recent-chip">
            <button class="recent-term" @click="store.openSearch(term)">
              <Icon name="history" :size="14" />
              {{ term }}
            </button>
            <button class="recent-x" :aria-label="`Remove “${term}” from recent searches`" @click="store.forgetSearch(term)">
              <Icon name="x" :size="12" />
            </button>
          </li>
        </ul>
      </section>

      <section class="block" aria-labelledby="browse-title">
        <div class="block-head">
          <h2 id="browse-title" class="section-title">Browse by mood</h2>
        </div>
        <ul class="moods" role="list">
          <li v-for="m in moods" :key="m.label">
            <button class="mood" :style="{ '--h': m.hue }" @click="store.openSearch(m.query)">
              <span class="mood-label">{{ m.label }}</span>
              <span class="mood-icon" aria-hidden="true"><Icon :name="m.icon" :size="34" /></span>
            </button>
          </li>
        </ul>
      </section>

      <p class="tip">
        <Icon name="link" :size="15" />
        Tip: paste a YouTube link into the search bar to play that exact video.
      </p>
    </template>

    <div v-else-if="state.searching" class="results" aria-busy="true" aria-label="Searching">
      <div class="top-grid">
        <div class="top-card skeleton-card">
          <span class="skeleton" style="width: 10rem; height: 10rem; border-radius: 1.2rem" />
          <span class="skeleton" style="width: 70%; height: 2.4rem; margin-top: 1.6rem" />
          <span class="skeleton" style="width: 40%; height: 1.6rem; margin-top: 0.8rem" />
        </div>
        <div class="sk-rows">
          <div v-for="i in 4" :key="i" class="sk-row">
            <span class="skeleton" style="width: 4.4rem; height: 4.4rem; border-radius: 0.8rem" />
            <span class="sk-lines">
              <span class="skeleton" :style="{ width: 40 + i * 9 + '%', height: '1.4rem' }" />
              <span class="skeleton" :style="{ width: 20 + i * 5 + '%', height: '1.2rem' }" />
            </span>
          </div>
        </div>
      </div>
      <span class="sr-only" role="status">Searching for {{ q }}</span>
    </div>

    <div v-else-if="state.searchError" class="empty-state" role="alert">
      <span class="badge danger"><Icon name="alert" :size="26" /></span>
      <h3>Something went wrong</h3>
      <p>{{ state.searchError }}</p>
      <button class="btn btn-secondary" @click="store.retrySearch()"><Icon name="rotate-ccw" :size="15" /> Try again</button>
    </div>

    <div v-else-if="!results.length && store.youtubeConfigured" class="empty-state" role="status">
      <span class="badge"><Icon name="search" :size="26" /></span>
      <h3>No results for “{{ q }}”</h3>
      <p>Check the spelling, try fewer words, or paste a YouTube link.</p>
    </div>

    <div v-else-if="results.length" class="results">
      <span class="sr-only" role="status">{{ results.length }} results for {{ q }}</span>
      <div class="top-grid">
        <section aria-labelledby="top-title">
          <h2 id="top-title" class="section-title block-title">Top result</h2>
          <div
            v-if="top"
            class="top-card"
            :class="{ current: topIsCurrent }"
            @dblclick="playTop"
            @contextmenu.prevent="store.openTrackMenu(top.id, anchorFrom($event))"
          >
            <Cover :src="top.thumbnail ?? null" :hue="top.hue" :size="104" :radius="12" />
            <h3 class="top-title">{{ top.title }}</h3>
            <p class="top-sub"><span class="pill">Song</span> {{ top.artist }} · {{ formatTime(top.duration) }}</p>
            <div class="top-actions">
              <button
                class="icon-btn"
                :class="{ liked: store.isFavorite(top.id) }"
                :aria-label="store.isFavorite(top.id) ? 'Remove from Liked Songs' : 'Add to Liked Songs'"
                @click="store.toggleFavorite(top.id)"
              >
                <Icon name="heart" :size="19" :filled="store.isFavorite(top.id)" />
              </button>
              <button class="icon-btn" aria-label="Add to queue" @click="store.addToQueue(top)">
                <Icon name="list-plus" :size="19" />
              </button>
              <button
                class="play-fab"
                :aria-label="topIsCurrent && state.isPlaying ? `Pause ${top.title}` : `Play ${top.title}`"
                @click="playTop"
              >
                <Icon :name="topIsCurrent && state.isPlaying ? 'pause' : 'play'" :size="22" />
              </button>
            </div>
          </div>
        </section>

        <section v-if="topSongs.length" aria-labelledby="songs-title">
          <h2 id="songs-title" class="section-title block-title">Songs</h2>
          <div class="rows" role="list">
            <TrackRow
              v-for="(song, i) in topSongs"
              :key="song.id"
              role="listitem"
              :song="song"
              :index="i + 1"
              :context="results"
              :from="from"
            />
          </div>
        </section>
      </div>

      <section v-if="more.length" class="block" aria-labelledby="more-title">
        <h2 id="more-title" class="section-title block-title">More results</h2>
        <div class="rows" role="list">
          <TrackRow
            v-for="(song, i) in more"
            :key="song.id"
            role="listitem"
            :song="song"
            :index="i + 5"
            :context="results"
            :from="from"
          />
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.search-view {
  display: flex;
  flex-direction: column;
  gap: 3rem;
  padding-top: 1.4rem;
}

.notice {
  display: flex;
  gap: 1.2rem;
  align-items: flex-start;
  padding: 1.4rem 1.6rem;
  border-radius: var(--r-lg);
  background: var(--fill-1);
  border: 0.1rem solid var(--line-2);
}

.notice.warn {
  background: rgba(255, 196, 92, 0.08);
  border-color: rgba(255, 196, 92, 0.32);
  color: #ffd38a;
}

.notice div {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.notice span {
  color: var(--text-dim);
  font-size: 1.3rem;
}

.block-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.4rem;
}

.block-title {
  margin-bottom: 1.4rem;
}

.recent {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-wrap: wrap;
  gap: 0.8rem;
}

.recent-chip {
  display: flex;
  align-items: center;
  height: 3.4rem;
  border-radius: var(--r-pill);
  background: var(--fill-2);
  border: 0.1rem solid var(--line);
  transition: background-color 0.15s var(--ease);
}

.recent-chip:hover {
  background: var(--fill-3);
}

.recent-term {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  height: 100%;
  padding: 0 0.6rem 0 1.3rem;
  border-radius: var(--r-pill) 0 0 var(--r-pill);
  font-size: 1.3rem;
  font-weight: 600;
  color: var(--text-h);
}

.recent-term svg {
  color: var(--text-faint);
}

.recent-x {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.6rem;
  height: 2.6rem;
  margin-right: 0.4rem;
  border-radius: 50%;
  color: var(--text-faint);
}

.recent-x:hover {
  background: var(--fill-3);
  color: var(--text-h);
}

.moods {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(18rem, 1fr));
  gap: 1.2rem;
}

.mood {
  position: relative;
  display: block;
  width: 100%;
  height: 10.4rem;
  padding: 1.4rem 1.6rem;
  border-radius: var(--r-lg);
  overflow: hidden;
  text-align: left;
  background:
    radial-gradient(circle at 90% 110%, hsla(calc(var(--h) + 40), 90%, 60%, 0.55), transparent 55%),
    linear-gradient(140deg, hsl(var(--h), 62%, 42%), hsl(calc(var(--h) + 25), 55%, 24%));
  transition:
    transform 0.2s var(--ease),
    box-shadow 0.2s var(--ease);
}

.mood:hover {
  transform: translateY(-0.3rem);
  box-shadow: 0 1.4rem 3rem -1.2rem hsla(var(--h), 80%, 50%, 0.6);
}

.mood:active {
  transform: scale(0.98);
}

.mood-label {
  position: relative;
  z-index: 1;
  font-size: 1.7rem;
  font-weight: 800;
  letter-spacing: -0.01em;
  color: #fff;
  text-shadow: 0 0.1rem 0.8rem rgba(0, 0, 0, 0.35);
}

.mood-icon {
  position: absolute;
  right: 1.2rem;
  bottom: 1rem;
  color: rgba(255, 255, 255, 0.8);
  transform: rotate(14deg);
  transition: transform 0.3s var(--ease-spring);
}

.mood:hover .mood-icon {
  transform: rotate(0) scale(1.12);
}

.tip {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  font-size: 1.3rem;
  color: var(--text-dim);
}

.tip svg {
  color: var(--accent);
}

.top-grid {
  display: grid;
  grid-template-columns: minmax(28rem, 2fr) 3fr;
  gap: 2.4rem;
  align-items: start;
}

.top-card {
  position: relative;
  display: flex;
  flex-direction: column;
  padding: 2rem;
  border-radius: var(--r-lg);
  background: var(--fill-2);
  transition: background-color 0.18s var(--ease);
}

.top-card:hover {
  background: var(--fill-3);
}

.top-card.current {
  background: var(--accent-soft);
  box-shadow: inset 0 0 0 0.1rem var(--accent-line);
}

.top-card :deep(.cover) {
  box-shadow: 0 1.2rem 3rem -1rem rgba(0, 0, 0, 0.7);
}

.top-title {
  margin-top: 1.6rem;
  font-size: 2.4rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.15;
  color: var(--text-h);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.top-card.current .top-title {
  color: var(--accent);
}

.top-sub {
  margin-top: 0.6rem;
  font-size: 1.35rem;
  color: var(--text-dim);
}

.pill {
  display: inline-block;
  margin-right: 0.4rem;
  padding: 0.2rem 0.9rem;
  border-radius: var(--r-pill);
  background: rgba(0, 0, 0, 0.35);
  color: var(--text-h);
  font-size: 1.15rem;
  font-weight: 750;
}

.top-actions {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  margin-top: 1.4rem;
}

.top-actions .play-fab {
  margin-left: auto;
}

.rows {
  display: flex;
  flex-direction: column;
  gap: var(--row-gap);
}

.results {
  display: flex;
  flex-direction: column;
  gap: 3rem;
}

.skeleton-card {
  min-height: 22rem;
}

.sk-rows {
  display: flex;
  flex-direction: column;
  gap: 1.2rem;
  padding-top: 4rem;
}

.sk-row {
  display: flex;
  align-items: center;
  gap: 1.2rem;
  padding: 0 1rem;
}

.sk-lines {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.badge.danger {
  background: var(--danger-soft);
  color: var(--danger);
}
</style>
