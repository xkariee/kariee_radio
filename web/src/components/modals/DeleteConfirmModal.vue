<script setup lang="ts">
import { computed } from 'vue'
import { store } from '../../store'
import { plural } from '../../utils/format'
import Modal from '../Modal.vue'
import Icon from '../Icon.vue'

const playlist = computed(() =>
  store.state.deletePlaylistId != null ? store.playlistById(store.state.deletePlaylistId) : null,
)

const others = computed(() => playlist.value?.collaborators.length ?? 0)
</script>

<template>
  <Modal v-if="playlist" title="Delete playlist?" :width="400" icon="trash-2" tone="danger" @close="store.cancelDeletePlaylist()">
    <p class="message">
      <b>“{{ playlist.name }}”</b> and its {{ plural(playlist.songIds.length, 'song') }} will be removed
      <template v-if="others"> for you and {{ plural(others, 'collaborator') }}</template>. This can’t be
      undone.
    </p>
    <template #footer>
      <button type="button" class="btn btn-quiet" @click="store.cancelDeletePlaylist()">Keep it</button>
      <button type="button" class="btn btn-danger-solid" @click="store.confirmDeletePlaylist()">
        <Icon name="trash-2" :size="14" /> Delete
      </button>
    </template>
  </Modal>
</template>

<style scoped>
.message {
  font-size: 1.4rem;
  line-height: 1.6;
  color: var(--text-dim);
}

.message b {
  color: var(--text-h);
  font-weight: 700;
}
</style>
