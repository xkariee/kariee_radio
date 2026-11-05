<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { store } from '../store'
import { relativeTime } from '../utils/format'
import Icon from './Icon.vue'
import HomeView from './views/HomeView.vue'
import SearchView from './views/SearchView.vue'
import QueueView from './views/QueueView.vue'
import CollectionView from './views/CollectionView.vue'
import AdminView from './views/AdminView.vue'

const { state } = store
const scroller = ref<HTMLElement | null>(null)

watch(
  () => [state.view, state.activePlaylistId],
  () => scroller.value?.scrollTo({ top: 0 }),
)

const ban = store.activeBan
const banUntil = computed(() =>
  ban.value?.expires_at ? `Ends ${relativeTime(ban.value.expires_at, state.now)}` : 'Permanent',
)
</script>

<template>
  <div ref="scroller" class="content">
    <div v-if="ban" class="ban-banner" role="alert">
      <span class="ban-icon" aria-hidden="true"><Icon name="ban" :size="18" /></span>
      <span class="ban-text">
        <b>{{ ban.scope === 'all' ? 'You’re banned from using the radio' : 'You’re banned from DJ booths' }}</b>
        <span>{{ ban.reason || 'No reason given' }} · {{ banUntil }}</span>
      </span>
    </div>
    <div v-else-if="state.djLocked && state.contextKind === 'dj'" class="ban-banner locked" role="status">
      <span class="ban-icon" aria-hidden="true"><Icon name="lock" :size="17" /></span>
      <span class="ban-text">
        <b>Only certain jobs can play music at this booth</b>
        <span>You can still browse, edit your playlists and change settings.</span>
      </span>
    </div>

    <Transition name="view" mode="out-in">
      <HomeView v-if="state.view === 'home'" key="home" />
      <SearchView v-else-if="state.view === 'search'" key="search" />
      <QueueView v-else-if="state.view === 'queue'" key="queue" />
      <AdminView v-else-if="state.view === 'admin' && state.isAdmin" key="admin" />
      <CollectionView v-else :key="`${state.view}:${state.activePlaylistId}`" />
    </Transition>
  </div>
</template>

<style scoped>
.content {
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 0.6rem 2.6rem 2.8rem;
}

.ban-banner {
  display: flex;
  align-items: center;
  gap: 1.2rem;
  margin: 0.8rem 0 0.4rem;
  padding: 1.2rem 1.4rem;
  border-radius: var(--r-lg);
  background: var(--danger-soft);
  border: 0.1rem solid rgba(255, 123, 123, 0.35);
}

.ban-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3.6rem;
  height: 3.6rem;
  border-radius: 50%;
  background: rgba(255, 123, 123, 0.18);
  color: var(--danger);
  flex-shrink: 0;
}

.ban-text {
  display: flex;
  flex-direction: column;
  font-size: 1.25rem;
  color: var(--text-dim);
}

.ban-text b {
  font-size: 1.4rem;
  color: var(--text-h);
}

.ban-banner.locked {
  background: var(--fill-2);
  border-color: var(--line-2);
}

.locked .ban-icon {
  background: var(--accent-soft);
  color: var(--accent);
}
</style>
