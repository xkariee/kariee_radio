<script setup lang="ts">
import { ref, watch } from 'vue'
import { store } from '../store'
import HomeView from './views/HomeView.vue'
import SearchView from './views/SearchView.vue'
import QueueView from './views/QueueView.vue'
import CollectionView from './views/CollectionView.vue'

const { state } = store
const scroller = ref<HTMLElement | null>(null)

watch(
  () => [state.view, state.activePlaylistId],
  () => scroller.value?.scrollTo({ top: 0 }),
)
</script>

<template>
  <div ref="scroller" class="content">
    <Transition name="view" mode="out-in">
      <HomeView v-if="state.view === 'home'" key="home" />
      <SearchView v-else-if="state.view === 'search'" key="search" />
      <QueueView v-else-if="state.view === 'queue'" key="queue" />
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
</style>
