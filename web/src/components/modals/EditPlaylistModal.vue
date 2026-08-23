<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { store } from '../../store'
import Modal from '../Modal.vue'
import CoverPicker from '../CoverPicker.vue'
import Icon from '../Icon.vue'

const playlist = computed(() =>
  store.state.editPlaylistId ? store.playlistById(store.state.editPlaylistId) : null,
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
  if (!playlist.value) return
  store.renamePlaylist(playlist.value.id, name.value)
  store.setPlaylistCover(playlist.value.id, cover.value)
  close()
}

function remove() {
  if (!playlist.value) return
  store.requestDeletePlaylist(playlist.value.id)
}
</script>

<template>
  <Modal v-if="playlist" title="Edit Playlist" @close="close">
    <form class="form" @submit.prevent="save">
      <label class="field">
        <span>Name</span>
        <input v-model="name" type="text" class="text-input" maxlength="60" autofocus />
      </label>
      <label class="field">
        <span>Cover</span>
        <CoverPicker v-model="cover" :hue="playlist.hue" />
      </label>
      <div class="form-actions">
        <button type="button" class="btn-danger" @click="remove">
          <Icon name="trash-2" :size="13" /> Delete
        </button>
        <div class="spacer" />
        <button type="button" class="btn-secondary" @click="close">Cancel</button>
        <button type="submit" class="btn-primary" :disabled="!name.trim()">Save Changes</button>
      </div>
    </form>
  </Modal>
</template>

<style scoped>
.form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.field > span {
  font-size: 11.5px;
  font-weight: 600;
  color: var(--text-faint);
}

.form-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 4px;
}

.spacer {
  flex: 1;
}
</style>
