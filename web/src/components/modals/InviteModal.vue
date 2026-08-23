<script setup lang="ts">
import { computed, ref } from 'vue'
import { store } from '../../store'
import Modal from '../Modal.vue'
import Icon from '../Icon.vue'

const playlist = computed(() =>
  store.state.inviteePlaylistId ? store.playlistById(store.state.inviteePlaylistId) : null,
)

const query = ref('')

const owner = computed(() => (playlist.value ? store.state.users.find((u) => u.id === playlist.value!.ownerId) : null))

const members = computed(() =>
  (playlist.value?.collaboratorIds ?? [])
    .map((id) => store.state.users.find((u) => u.id === id))
    .filter((u): u is NonNullable<typeof u> => !!u),
)

const candidates = computed(() => {
  const pl = playlist.value
  if (!pl) return []
  const q = query.value.trim().toLowerCase()
  return store.state.users.filter(
    (u) => u.id !== pl.ownerId && !pl.collaboratorIds.includes(u.id) && (!q || u.name.toLowerCase().includes(q)),
  )
})

function close() {
  store.state.inviteePlaylistId = null
  query.value = ''
}

function invite(userId: string) {
  if (playlist.value) store.inviteUser(playlist.value.id, userId)
}

function remove(userId: string) {
  if (playlist.value) store.removeCollaborator(playlist.value.id, userId)
}
</script>

<template>
  <Modal v-if="playlist" :title="`Invite to “${playlist.name}”`" :width="360" @close="close">
    <div class="invite-body">
      <input v-model="query" type="text" class="text-input" placeholder="Search people..." />

      <div class="section">
        <span class="section-label">Members</span>
        <div class="member-row" v-if="owner">
          <span class="avatar" :style="{ background: owner.color }">{{ owner.name[0] }}</span>
          <span class="name">{{ owner.name }}</span>
          <span class="role">Owner</span>
        </div>
        <div class="member-row" v-for="u in members" :key="u.id">
          <span class="avatar" :style="{ background: u.color }">{{ u.name[0] }}</span>
          <span class="name">{{ u.name }}</span>
          <button class="btn-icon ghost" title="Remove" @click="remove(u.id)">
            <Icon name="x" :size="14" />
          </button>
        </div>
      </div>

      <div class="section" v-if="candidates.length">
        <span class="section-label">Add people</span>
        <div class="member-row" v-for="u in candidates" :key="u.id">
          <span class="avatar" :style="{ background: u.color }">{{ u.name[0] }}</span>
          <span class="name">{{ u.name }}</span>
          <button class="btn-secondary sm" @click="invite(u.id)">
            <Icon name="user-plus" :size="12" /> Add
          </button>
        </div>
      </div>
      <p v-else-if="query" class="empty-hint">No one found matching "{{ query }}".</p>
    </div>
  </Modal>
</template>

<style scoped>
.invite-body {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.section {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.section-label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--text-faint);
  margin-bottom: 6px;
}

.member-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 6px;
  border-radius: var(--radius-sm);
  transition: background-color 0.12s var(--ease);
}

.member-row:hover {
  background: var(--surface-3);
}

.avatar {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  color: rgba(0, 0, 0, 0.55);
  flex-shrink: 0;
  box-shadow: 0 0 0 2px var(--surface-2);
}

.name {
  flex: 1;
  font-size: 13px;
  color: var(--text);
}

.role {
  font-size: 11px;
  color: var(--text-faint);
}

.btn-secondary.sm {
  padding: 5px 9px;
  font-size: 11.5px;
}

.empty-hint {
  font-size: 12.5px;
  color: var(--text-faint);
  text-align: center;
  padding: 8px 0;
}
</style>
