<script setup lang="ts">
import { onMounted, ref } from 'vue'
import TopBar from './components/TopBar.vue'
import Sidebar from './components/Sidebar.vue'
import MainContent from './components/MainContent.vue'
import PlayerBar from './components/PlayerBar.vue'
import ContextMenu from './components/ContextMenu.vue'
import CreatePlaylistModal from './components/modals/CreatePlaylistModal.vue'
import EditPlaylistModal from './components/modals/EditPlaylistModal.vue'
import InviteModal from './components/modals/InviteModal.vue'
import DeleteConfirmModal from './components/modals/DeleteConfirmModal.vue'
import Icon from './components/Icon.vue'
import { store } from './store'

// `visible` mirrors what a real NUI focus toggle (F-key bind -> SetNuiFocus)
// would drive; wired here to a close button + reopen tab for the browser demo.
const visible = ref(true)

onMounted(() => store.initYoutubePlayer('yt-player-host'))
</script>

<template>
  <div class="stage">
    <Transition name="pop" appear>
      <div v-if="visible" class="panel">
        <div class="panel-glow" />
        <TopBar @close="visible = false" />
        <div class="panel-body">
          <Sidebar />
          <MainContent />
        </div>
        <PlayerBar />
      </div>

      <button v-else class="reopen-tab" @click="visible = true">
        <Icon name="disc" :size="15" />
        Open Radio
      </button>
    </Transition>

    <ContextMenu />
    <CreatePlaylistModal v-if="store.state.createPlaylistOpen" />
    <EditPlaylistModal v-if="store.state.editPlaylistId" />
    <InviteModal v-if="store.state.inviteePlaylistId" />
    <DeleteConfirmModal v-if="store.state.deletePlaylistId" />

    <!-- hidden host for the YouTube IFrame player that powers real playback -->
    <div id="yt-player-host" class="yt-host" />
  </div>
</template>

<style scoped>
.stage {
  width: 100%;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
}

.panel {
  position: relative;
  width: 70vw;
  height: 76vh;
  min-width: 860px;
  min-height: 520px;
  max-width: 1360px;
  max-height: 860px;
  background: var(--surface-1);
  border: 1px solid var(--line);
  border-radius: var(--radius-xl);
  box-shadow:
    0 1px 0 rgba(255, 255, 255, 0.04) inset,
    var(--shadow-lg);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.panel-glow {
  position: absolute;
  inset: 0;
  background: radial-gradient(ellipse 900px 300px at 20% -10%, rgba(45, 212, 191, 0.08), transparent 60%);
  pointer-events: none;
}

.panel-body {
  flex: 1;
  display: flex;
  min-height: 0;
}

.reopen-tab {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: var(--surface-2);
  border: 1px solid var(--line);
  color: var(--text);
  padding: 11px 20px;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 600;
  box-shadow: var(--shadow-md);
  transition:
    border-color 0.15s var(--ease),
    color 0.15s var(--ease),
    transform 0.15s var(--ease);
}

.reopen-tab svg {
  color: var(--teal);
}

.reopen-tab:hover {
  border-color: var(--teal-line);
  color: var(--teal);
  transform: translateY(-1px);
}

.yt-host {
  position: fixed;
  width: 1px;
  height: 1px;
  overflow: hidden;
  opacity: 0;
  pointer-events: none;
}
</style>
