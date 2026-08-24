<script setup lang="ts">
import { onMounted } from 'vue'
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

// `state.visible` mirrors the real NUI focus toggle - hidden until the client sends `open`
// (via /radio, /createdj or /radiocar), driven entirely by client/main.lua in the FiveM build.
// In the plain-browser dev fallback it just starts visible with a close/reopen tab.
onMounted(() => store.bindNui())

function close() {
  if (store.isNuiEnv) store.close()
  else store.state.visible = false
}
</script>

<template>
  <div class="stage">
    <Transition name="pop" appear>
      <div v-if="store.state.visible" class="panel">
        <div class="panel-glow" />
        <TopBar @close="close" />
        <div class="panel-body">
          <Sidebar />
          <MainContent />
        </div>
        <PlayerBar />
      </div>

      <button v-else-if="!store.isNuiEnv" class="reopen-tab" @click="store.state.visible = true">
        <Icon name="disc" :size="15" />
        Open Radio
      </button>
    </Transition>

    <ContextMenu />
    <CreatePlaylistModal v-if="store.state.createPlaylistOpen" />
    <EditPlaylistModal v-if="store.state.editPlaylistId" />
    <InviteModal v-if="store.state.inviteePlaylistId" />
    <DeleteConfirmModal v-if="store.state.deletePlaylistId" />
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
</style>
