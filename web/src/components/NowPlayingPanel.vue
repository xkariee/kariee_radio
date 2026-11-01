<script setup lang="ts">
import { computed } from 'vue'
import { store } from '../store'
import { settings } from '../settings'
import { anchorFrom } from '../utils/menu'
import Icon from './Icon.vue'
import Cover from './Cover.vue'

const { state } = store
const song = store.currentSong

const hiRes = computed(() =>
  song.value?.videoId ? `https://i.ytimg.com/vi/${song.value.videoId}/maxresdefault.jpg` : null,
)

const nextFew = computed(() => store.upNext.value.slice(0, 4))

const sleepLabel = computed(() => {
  if (state.sleepEndOfTrack) return 'Stops after this song'
  const s = store.sleepRemaining.value
  if (s == null) return null
  return `Stops in ${store.formatTime(s)}`
})

function goToSource() {
  const nav = state.playingFrom?.nav
  if (!nav) return
  if (nav.view === 'search') store.openSearch()
  else store.setView(nav.view, nav.playlistId)
}
</script>

<template>
  <aside class="panel rail" aria-label="Now playing">
    <div v-if="settings.ambient && song" class="ambient" aria-hidden="true">
      <img v-if="song.thumbnail" :src="song.thumbnail" alt="" />
    </div>

    <header class="rail-head">
      <h2 class="eyebrow">Now playing</h2>
      <button class="icon-btn sm" aria-label="Hide now playing panel" title="Hide panel (N)" @click="settings.nowPlayingPanel = false">
        <Icon name="panel-right" :size="17" />
      </button>
    </header>

    <div v-if="song" class="rail-body">
      <div class="stage" :class="{ playing: state.isPlaying }">
        <div class="vinyl" aria-hidden="true">
          <div class="vinyl-spin">
            <span class="vinyl-label" :style="{ '--h': song.hue }">
              <img v-if="song.thumbnail" :src="song.thumbnail" alt="" />
            </span>
          </div>
          <span class="vinyl-sheen" />
        </div>
        <div class="art">
          <Cover :key="song.id" :src="song.thumbnail ?? null" :hi-src="hiRes" :hue="song.hue" size="fill" :radius="16" />
        </div>
      </div>

      <div class="np-meta">
        <div class="np-text">
          <p class="np-title" :title="song.title">{{ song.title }}</p>
          <button class="np-artist truncate" :title="`Search for ${song.artist}`" @click="store.openSearch(song.artist)">
            {{ song.artist }}
          </button>
        </div>
        <button
          class="icon-btn"
          :class="{ liked: store.isFavorite(song.id) }"
          :aria-label="store.isFavorite(song.id) ? 'Remove from Liked Songs' : 'Add to Liked Songs'"
          @click="store.toggleFavorite(song.id)"
        >
          <Icon name="heart" :size="20" :filled="store.isFavorite(song.id)" />
        </button>
      </div>

      <div class="np-actions">
        <button class="chip" @click="store.openTrackMenu(song.id, anchorFrom($event))">
          <Icon name="folder-plus" :size="15" /> Save
        </button>
        <button v-if="song.videoId" class="chip" @click="store.copyLink(song)">
          <Icon name="link" :size="15" /> Copy link
        </button>
      </div>

      <button v-if="state.playingFrom" class="from" :disabled="!state.playingFrom.nav" @click="goToSource">
        <span class="from-k">Playing from</span>
        <span class="from-v truncate">{{ state.playingFrom.label }}</span>
        <Icon name="chevron-right" :size="15" />
      </button>

      <div v-if="sleepLabel" class="sleep">
        <Icon name="moon" :size="16" />
        <span>{{ sleepLabel }}</span>
        <button class="btn btn-quiet sm" @click="store.setSleepTimer(null)">Cancel</button>
      </div>

      <section class="next" aria-labelledby="rail-next">
        <div class="next-head">
          <h3 id="rail-next" class="eyebrow">Next up</h3>
          <button class="link" @click="store.setView('queue')">Open queue</button>
        </div>
        <ul v-if="nextFew.length" class="next-list" role="list">
          <li v-for="entry in nextFew" :key="entry.qid">
            <button class="next-row" :title="`Play ${store.songById(entry.songId)?.title} now`" @click="store.jumpTo(entry.qid)">
              <Cover
                :src="store.songById(entry.songId)?.thumbnail ?? null"
                :hue="store.songById(entry.songId)?.hue ?? 0"
                :size="38"
                :radius="8"
              />
              <span class="next-meta">
                <span class="next-title truncate">{{ store.songById(entry.songId)?.title }}</span>
                <span class="next-artist truncate">{{ store.songById(entry.songId)?.artist }}</span>
              </span>
            </button>
          </li>
        </ul>
        <p v-else class="next-empty">Nothing queued. Songs you add will play after this one.</p>
      </section>
    </div>

    <div v-else class="rail-empty">
      <div class="stage idle" aria-hidden="true">
        <div class="vinyl">
          <div class="vinyl-spin"><span class="vinyl-label" style="--h: 330" /></div>
          <span class="vinyl-sheen" />
        </div>
      </div>
      <p class="empty-title">Nothing playing</p>
      <p class="empty-sub">Pick a playlist or search for a song. It’ll show up here.</p>
      <button class="btn btn-primary sm" @click="store.openSearch()"><Icon name="search" :size="14" /> Find music</button>
    </div>
  </aside>
</template>

<style scoped>
.rail {
  display: flex;
  flex-direction: column;
}

.ambient {
  position: absolute;
  inset: 0 0 auto;
  height: 46rem;
  overflow: hidden;
  pointer-events: none;
  -webkit-mask-image: linear-gradient(to bottom, #000 30%, transparent);
  mask-image: linear-gradient(to bottom, #000 30%, transparent);
}

.ambient img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: blur(4.8rem) saturate(1.5);
  opacity: 0.42;
  transform: scale(1.4);
}

.rail-head {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.4rem 1.2rem 0.4rem 2rem;
}

.rail-head .eyebrow {
  color: var(--text-dim);
}

.rail-body {
  position: relative;
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 1rem 2rem 2rem;
  display: flex;
  flex-direction: column;
  gap: 1.6rem;
}

/* ─── artwork + vinyl that slides out while playing ─── */

.stage {
  position: relative;
  width: 100%;
  aspect-ratio: 1.12;
  flex-shrink: 0;
}

.art {
  position: absolute;
  left: 0;
  top: 0;
  width: 80%;
  z-index: 1;
  border-radius: 1.6rem;
  box-shadow: 0 2.4rem 4.8rem -1.6rem rgba(0, 0, 0, 0.8);
  transition: transform 0.6s var(--ease-out);
}

.stage.playing .art {
  transform: translateX(-0.4rem);
}

.vinyl {
  position: absolute;
  top: 5%;
  left: 5%;
  width: 72%;
  aspect-ratio: 1;
  border-radius: 50%;
  transition: transform 0.8s var(--ease-out);
}

/* slides out from behind the sleeve while playing (stays inside the rail: 5 + 72 + 72*.28 < 100) */
.stage.playing .vinyl {
  transform: translateX(28%);
}

.vinyl-spin {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background:
    repeating-radial-gradient(circle at 50% 50%, #141217 0 0.15rem, #24212a 0.15rem 0.3rem),
    #141217;
  box-shadow:
    0 0 0 0.15rem rgba(255, 255, 255, 0.1),
    0 0 2.4rem -0.4rem var(--accent-glow),
    0 1.6rem 3.2rem -1rem rgba(0, 0, 0, 0.8);
  animation: spin 5s linear infinite;
  animation-play-state: paused;
}

.stage.playing .vinyl-spin {
  animation-play-state: running;
}

.vinyl-label {
  position: absolute;
  inset: 33%;
  border-radius: 50%;
  overflow: hidden;
  background: radial-gradient(circle, hsl(var(--h), 70%, 60%), hsl(var(--h), 60%, 30%));
  box-shadow: 0 0 0 0.3rem rgba(0, 0, 0, 0.5);
}

.vinyl-label img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.vinyl-label::after {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  width: 0.9rem;
  height: 0.9rem;
  margin: -0.45rem 0 0 -0.45rem;
  border-radius: 50%;
  background: #0c0b0e;
}

.vinyl-sheen {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background: conic-gradient(
    from 30deg,
    transparent 0deg,
    rgba(255, 255, 255, 0.14) 40deg,
    transparent 90deg,
    transparent 180deg,
    rgba(255, 255, 255, 0.1) 220deg,
    transparent 270deg
  );
  pointer-events: none;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

/* ─── meta ─── */

.np-meta {
  display: flex;
  align-items: flex-start;
  gap: 0.8rem;
}

.np-text {
  flex: 1;
  min-width: 0;
}

.np-title {
  font-size: 2rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.2;
  color: var(--text-h);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.np-artist {
  display: block;
  max-width: 100%;
  margin-top: 0.3rem;
  font-size: 1.4rem;
  font-weight: 600;
  color: var(--text-dim);
}

.np-artist:hover {
  color: var(--text-h);
  text-decoration: underline;
}

.np-actions {
  display: flex;
  gap: 0.6rem;
}

.from {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 1rem 1.2rem;
  border-radius: var(--r-md);
  background: var(--fill-1);
  border: 0.1rem solid var(--line);
  font-size: 1.25rem;
  color: var(--text-dim);
  transition: background-color 0.15s var(--ease);
}

.from:hover:not(:disabled) {
  background: var(--fill-2);
}

.from:disabled {
  opacity: 1;
  cursor: default;
}

.from-k {
  flex-shrink: 0;
}

.from-v {
  flex: 1;
  min-width: 0;
  font-weight: 700;
  color: var(--text-h);
  text-align: left;
}

.sleep {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  padding: 0.6rem 0.6rem 0.6rem 1.2rem;
  border-radius: var(--r-md);
  background: var(--accent-soft);
  color: var(--accent);
  font-size: 1.3rem;
  font-weight: 650;
}

.sleep span {
  flex: 1;
}

.next {
  display: flex;
  flex-direction: column;
  gap: 0.8rem;
}

.next-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.link {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--text-dim);
}

.link:hover {
  color: var(--text-h);
  text-decoration: underline;
}

.next-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.next-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  width: 100%;
  padding: 0.6rem;
  margin: 0 -0.6rem;
  border-radius: var(--r-md);
  text-align: left;
  transition: background-color 0.14s var(--ease);
}

.next-row:hover {
  background: var(--fill-2);
}

.next-meta {
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.next-title {
  font-size: 1.3rem;
  font-weight: 650;
  color: var(--text-h);
}

.next-artist {
  font-size: 1.15rem;
  color: var(--text-dim);
}

.next-empty {
  font-size: 1.25rem;
  color: var(--text-faint);
}

/* ─── empty ─── */

.rail-empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.8rem;
  padding: 2rem 2.4rem 4rem;
  text-align: center;
}

.stage.idle {
  width: 60%;
  aspect-ratio: 1;
  margin-bottom: 1.6rem;
}

.stage.idle .vinyl {
  inset: 0;
  width: 100%;
  top: 0;
  left: 0;
}

.empty-title {
  font-size: 1.7rem;
  font-weight: 750;
  color: var(--text-h);
}

.empty-sub {
  font-size: 1.3rem;
  color: var(--text-dim);
  margin-bottom: 0.8rem;
}
</style>
