<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { store } from '../../store'
import Modal from '../Modal.vue'
import CoverPicker from '../CoverPicker.vue'
import Icon from '../Icon.vue'

const playlist = computed(() =>
  store.state.editPlaylistId != null ? store.playlistById(store.state.editPlaylistId) : null,
)

const name = ref('')
const cover = ref<string | null>(null)

watch(
  playlist,
  (pl) => {
    if (pl) {
      name.value = pl.name
      cover.value = pl.cover
    }
  },
  { immediate: true },
)

function close() {
  store.state.editPlaylistId = null
}

function save() {
  if (!playlist.value || !name.value.trim()) return
  store.renamePlaylist(playlist.value.id, name.value)
  store.setPlaylistCover(playlist.value.id, cover.value)
  store.toast('Playlist updated', 'check')
  close()
}

function remove() {
  if (playlist.value) store.requestDeletePlaylist(playlist.value.id)
}
</script>

<template>
  <Modal v-if="playlist" title="Edit details" :subtitle="playlist.name" icon="edit-2" @close="close">
    <form id="edit-pl" class="form" @submit.prevent="save">
      <div class="field">
        <label for="edit-name">Name</label>
        <input id="edit-name" v-model="name" type="text" class="text-input" maxlength="60" required autofocus />
      </div>
      <CoverPicker v-model="cover" :hue="playlist.hue" />
    </form>
    <template #footer>
      <button type="button" class="btn btn-danger sm" @click="remove"><Icon name="trash-2" :size="14" /> Delete</button>
      <span class="spacer" />
      <button type="button" class="btn btn-quiet" @click="close">Cancel</button>
      <button type="submit" form="edit-pl" class="btn btn-primary" :disabled="!name.trim()">Save</button>
    </template>
  </Modal>
</template>

<style scoped>
.form {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.field label {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--text-dim);
}

.spacer {
  flex: 1;
}
</style>
