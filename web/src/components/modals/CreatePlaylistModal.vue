<script setup lang="ts">
import { ref } from 'vue'
import { store } from '../../store'
import Modal from '../Modal.vue'
import CoverPicker from '../CoverPicker.vue'

const name = ref('')
const cover = ref<string | null>(null)
const busy = ref(false)
const hue = Math.floor(Math.random() * 360)

function close() {
  store.state.createPlaylistOpen = false
}

async function create() {
  if (!name.value.trim() || busy.value) return
  busy.value = true
  await store.createPlaylist(name.value.trim(), cover.value)
  busy.value = false
}
</script>

<template>
  <Modal title="New playlist" subtitle="Collect songs and invite friends to add theirs." icon="plus" @close="close">
    <form id="create-pl" class="form" @submit.prevent="create">
      <div class="field">
        <label for="pl-name">Name</label>
        <input
          id="pl-name"
          v-model="name"
          type="text"
          class="text-input"
          placeholder="e.g. Late Night Cruising"
          maxlength="60"
          autofocus
          required
        />
        <span class="counter" aria-hidden="true">{{ name.length }}/60</span>
      </div>
      <CoverPicker v-model="cover" :hue="hue" />
    </form>
    <template #footer>
      <button type="button" class="btn btn-quiet" @click="close">Cancel</button>
      <button type="submit" form="create-pl" class="btn btn-primary" :disabled="!name.trim() || busy">
        Create playlist
      </button>
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
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.field label {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--text-dim);
}

.counter {
  position: absolute;
  right: 1.2rem;
  bottom: 1.1rem;
  font-size: 1.1rem;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
}
</style>
