<script setup lang="ts">
import { store } from '../../store'
import Modal from '../Modal.vue'
import Icon from '../Icon.vue'

// Generic "are you sure?" for destructive admin actions. Focus lands on Cancel by default.
const { state } = store

function confirm() {
  const c = state.confirm
  state.confirm = null
  c?.onConfirm()
}
</script>

<template>
  <Modal
    v-if="state.confirm"
    :title="state.confirm.title"
    :icon="state.confirm.icon"
    :tone="state.confirm.tone === 'danger' ? 'danger' : undefined"
    :width="420"
    @close="state.confirm = null"
  >
    <p class="message">{{ state.confirm.message }}</p>
    <template #footer>
      <button type="button" class="btn btn-quiet" @click="state.confirm = null">Cancel</button>
      <button
        type="button"
        class="btn"
        :class="state.confirm.tone === 'danger' ? 'btn-danger-solid' : 'btn-primary'"
        @click="confirm"
      >
        <Icon :name="state.confirm.icon" :size="14" /> {{ state.confirm.confirmLabel }}
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
</style>
