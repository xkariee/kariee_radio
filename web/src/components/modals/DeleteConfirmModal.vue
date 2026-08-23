<script setup lang="ts">
import { computed } from 'vue'
import { store } from '../../store'
import Modal from '../Modal.vue'
import Icon from '../Icon.vue'

const playlist = computed(() =>
  store.state.deletePlaylistId ? store.playlistById(store.state.deletePlaylistId) : null,
)

function close() {
  store.cancelDeletePlaylist()
}

function confirmDelete() {
  store.confirmDeletePlaylist()
}
</script>

<template>
  <Modal v-if="playlist" title="Delete Playlist" :width="360" @close="close">
    <div class="confirm-body">
      <span class="warn-badge">
        <Icon name="trash-2" :size="22" />
      </span>
      <p class="message">
        Delete <b>“{{ playlist.name }}”</b>? This will remove the playlist for everyone, including any
        collaborators. This cannot be undone.
      </p>
      <div class="form-actions">
        <button type="button" class="btn-secondary" @click="close">Cancel</button>
        <button type="button" class="btn-danger-solid" @click="confirmDelete">
          <Icon name="trash-2" :size="13" /> Delete Playlist
        </button>
      </div>
    </div>
  </Modal>
</template>

<style scoped>
.confirm-body {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  text-align: center;
}

.warn-badge {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 52px;
  height: 52px;
  border-radius: 50%;
  background: rgba(248, 113, 113, 0.1);
  border: 1px solid rgba(248, 113, 113, 0.3);
  color: var(--danger);
}

.message {
  font-size: 13px;
  line-height: 1.6;
  color: var(--text-faint);
}

.message b {
  color: var(--text-h);
  font-weight: 600;
}

.form-actions {
  display: flex;
  justify-content: center;
  gap: 8px;
  margin-top: 4px;
  width: 100%;
}

.form-actions .btn-secondary,
.form-actions .btn-danger-solid {
  flex: 1;
  justify-content: center;
}

.btn-danger-solid {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 8px 15px;
  border-radius: var(--radius-md);
  font-size: 12.5px;
  font-weight: 600;
  color: #fff;
  background: linear-gradient(155deg, #f87171, #dc2626);
  box-shadow: 0 1px 0 rgba(255, 255, 255, 0.2) inset, 0 4px 14px -4px rgba(220, 38, 38, 0.45);
  transition:
    transform 0.15s var(--ease),
    box-shadow 0.15s var(--ease);
}

.btn-danger-solid:hover {
  transform: translateY(-1px);
  box-shadow: 0 1px 0 rgba(255, 255, 255, 0.25) inset, 0 8px 20px -6px rgba(220, 38, 38, 0.5);
}

.btn-danger-solid:active {
  transform: translateY(0);
}
</style>
