<script setup lang="ts">
import { store } from '../store'
import Icon from './Icon.vue'
import TrackRow from './TrackRow.vue'
</script>

<template>
  <div class="search-view">
    <div class="library-header">
      <h1>Search Results</h1>
    </div>

    <div v-if="!store.youtubeConfigured" class="notice">
      <span class="notice-badge"><Icon name="search" :size="22" /></span>
      <p>There was an error.</p>
      <!-- <p class="hint">
        Add a YouTube Data API v3 key to <code>web/.env</code> as <code>VITE_YOUTUBE_API_KEY</code> to search and
        play songs straight from YouTube.
      </p> -->
    </div>

    <div v-else-if="store.state.searching" class="notice">
      <span class="notice-badge spin"><Icon name="search" :size="22" /></span>
      <p>Searching for "{{ store.state.searchQuery }}"...</p>
    </div>

    <div v-else-if="store.state.searchError" class="notice error">
      <span class="notice-badge error"><Icon name="search" :size="22" /></span>
      <p>{{ store.state.searchError }}</p>
    </div>

    <div v-else-if="!store.searchResults.value.length" class="notice">
      <span class="notice-badge"><Icon name="search" :size="22" /></span>
      <p>No results for "{{ store.state.searchQuery }}".</p>
    </div>

    <TransitionGroup v-else name="list" tag="div" class="track-list">
      <TrackRow
        v-for="(song, i) in store.searchResults.value"
        :key="song.id"
        :song="song"
        :index="i"
        :context="store.searchResults.value"
      />
    </TransitionGroup>
  </div>
</template>

<style scoped>
.search-view {
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

.track-list {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding-bottom: 12px;
}

.list-move,
.list-enter-active,
.list-leave-active {
  transition:
    transform 0.2s var(--ease),
    opacity 0.2s var(--ease);
}

.list-enter-from {
  opacity: 0;
  transform: translateY(-6px);
}

.list-leave-to {
  opacity: 0;
}

.list-leave-active {
  position: absolute;
  width: 100%;
}

.notice {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  color: var(--text-faint);
  padding: 48px 24px;
  font-size: 13px;
  text-align: center;
}

.notice-badge {
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

.notice-badge.spin {
  color: var(--teal);
  border-color: var(--teal-line);
  background: var(--teal-wash);
  animation: pulse-ring 1.4s ease-in-out infinite;
}

.notice-badge.error {
  color: var(--danger);
  border-color: rgba(248, 113, 113, 0.35);
  background: rgba(248, 113, 113, 0.08);
}

@keyframes pulse-ring {
  0%,
  100% {
    box-shadow: 0 0 0 0 rgba(45, 212, 191, 0.25);
  }
  50% {
    box-shadow: 0 0 0 8px rgba(45, 212, 191, 0);
  }
}

.notice p {
  max-width: 380px;
}

.notice.error p {
  color: var(--danger);
}

.hint {
  font-size: 12px;
  line-height: 1.6;
}

.hint code {
  background: var(--surface-3);
  border-radius: 4px;
  padding: 1px 6px;
  font-size: 11.5px;
  color: var(--teal);
}
</style>
