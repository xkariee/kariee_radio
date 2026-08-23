<script setup lang="ts">
import { ref } from 'vue'
import { store } from '../../store'
import Modal from '../Modal.vue'
import CoverPicker from '../CoverPicker.vue'

const name = ref('')
const cover = ref<string | null>(null)

function close() {
  store.state.createPlaylistOpen = false
  name.value = ''
  cover.value = null
}

function create() {
  if (!name.value.trim()) return
  store.createPlaylist(name.value, cover.value)
  name.value = ''
  cover.value = null
}
</script>

<template>
  <Modal title="New Playlist" @close="close">
    <form class="form" @submit.prevent="create">
      <label class="field">
        <span>Name</span>
        <input v-model="name" type="text" class="text-input" placeholder="My Playlist" autofocus maxlength="60" />
      </label>
      <label class="field">
        <span>Cover</span>
        <CoverPicker v-model="cover" :hue="200" />
      </label>
      <div class="form-actions">
        <button type="button" class="btn-secondary" @click="close">Cancel</button>
        <button type="submit" class="btn-primary" :disabled="!name.trim()">Create Playlist</button>
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
  justify-content: flex-end;
  gap: 8px;
  margin-top: 4px;
}
</style>
