<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { OnlineCandidate } from '../../types'
import { store } from '../../store'
import { colorForId } from '../../utils/avatar'
import Modal from '../Modal.vue'
import Icon from '../Icon.vue'

const playlist = computed(() =>
  store.state.inviteePlaylistId != null ? store.playlistById(store.state.inviteePlaylistId) : null,
)

const isOwner = computed(() => playlist.value?.ownerIdentifier === store.state.identifier)

const query = ref('')
const invited = ref(new Set<number>())

watch(query, (q) => store.searchCandidates(q))
store.searchCandidates('')

const candidates = computed(() => {
  const pl = playlist.value
  if (!pl) return []
  const memberIdentifiers = new Set(pl.collaborators.map((c) => c.identifier))
  return store.state.candidates.filter((c) => !memberIdentifiers.has(String(c.id)))
})

function close() {
  store.state.inviteePlaylistId = null
}

async function invite(target: OnlineCandidate) {
  if (!playlist.value) return
  invited.value = new Set(invited.value).add(target.id)
  await store.inviteUser(playlist.value.id, target)
}
</script>

<template>
  <Modal v-if="playlist" title="Invite people" :subtitle="`to “${playlist.name}”`" icon="user-plus" :width="440" @close="close">
    <div class="body">
      <div class="search">
        <Icon name="search" :size="16" />
        <label class="sr-only" for="invite-q">Search online players</label>
        <input id="invite-q" v-model="query" type="text" placeholder="Search online players" autocomplete="off" />
        <span v-if="store.state.candidateSearching" class="spinner" aria-hidden="true" />
      </div>

      <section aria-labelledby="add-label">
        <h3 id="add-label" class="eyebrow label">Online now</h3>
        <ul v-if="candidates.length" class="people" role="list">
          <li v-for="c in candidates" :key="c.id" class="person">
            <span class="avatar" :style="{ background: colorForId(String(c.id)) }" aria-hidden="true">{{ c.name[0] }}</span>
            <span class="p-name truncate">{{ c.name }}</span>
            <span class="p-id">ID {{ c.id }}</span>
            <button
              class="btn sm"
              :class="invited.has(c.id) ? 'btn-quiet' : 'btn-secondary'"
              :disabled="invited.has(c.id)"
              :aria-label="invited.has(c.id) ? `Invite sent to ${c.name}` : `Invite ${c.name}`"
              @click="invite(c)"
            >
              <Icon :name="invited.has(c.id) ? 'check' : 'user-plus'" :size="14" />
              {{ invited.has(c.id) ? 'Sent' : 'Invite' }}
            </button>
          </li>
        </ul>
        <p v-else class="none">
          {{ query ? `No one online matches “${query}”.` : 'No other players online right now.' }}
        </p>
      </section>

      <section aria-labelledby="members-label">
        <h3 id="members-label" class="eyebrow label">Members · {{ playlist.collaborators.length + 1 }}</h3>
        <ul class="people" role="list">
          <li class="person">
            <span class="avatar" :style="{ background: colorForId(playlist.ownerIdentifier) }" aria-hidden="true">
              {{ playlist.ownerName[0] }}
            </span>
            <span class="p-name truncate">{{ playlist.ownerName }}</span>
            <span class="role">Owner</span>
          </li>
          <li v-for="c in playlist.collaborators" :key="c.identifier" class="person">
            <span class="avatar" :style="{ background: colorForId(c.identifier) }" aria-hidden="true">{{ c.name[0] }}</span>
            <span class="p-name truncate">{{ c.name }}</span>
            <button
              v-if="isOwner"
              class="icon-btn sm remove"
              :aria-label="`Remove ${c.name} from playlist`"
              title="Remove"
              @click="store.removeCollaborator(playlist.id, c.identifier)"
            >
              <Icon name="x" :size="15" />
            </button>
            <span v-else class="role">Collaborator</span>
          </li>
        </ul>
      </section>
    </div>
  </Modal>
</template>

<style scoped>
.body {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.search {
  display: flex;
  align-items: center;
  gap: 1rem;
  height: 4.4rem;
  padding: 0 1.4rem;
  border-radius: var(--r-pill);
  background: var(--fill-2);
  border: 0.1rem solid var(--line-2);
  color: var(--text-faint);
}

.search:focus-within {
  border-color: var(--accent-line);
  box-shadow: 0 0 0 0.3rem var(--accent-soft);
}

.search input {
  flex: 1;
  min-width: 0;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-h);
  font-size: 1.4rem;
}

.search input::placeholder {
  color: var(--text-faint);
}

.spinner {
  width: 1.6rem;
  height: 1.6rem;
  border-radius: 50%;
  border: 0.2rem solid var(--fill-4);
  border-top-color: var(--accent);
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.label {
  margin-bottom: 0.8rem;
}

.people {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  max-height: 22rem;
  overflow-y: auto;
}

.person {
  display: flex;
  align-items: center;
  gap: 1.1rem;
  min-height: 4.8rem;
  padding: 0 0.8rem;
  border-radius: var(--r-md);
}

.person:hover {
  background: var(--fill-2);
}

.avatar {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3.4rem;
  height: 3.4rem;
  border-radius: 50%;
  font-size: 1.3rem;
  font-weight: 800;
  color: rgba(0, 0, 0, 0.62);
  flex-shrink: 0;
}

.p-name {
  flex: 1;
  min-width: 0;
  font-size: 1.4rem;
  font-weight: 650;
  color: var(--text-h);
}

.p-id {
  font-size: 1.15rem;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
}

.role {
  font-size: 1.2rem;
  font-weight: 600;
  color: var(--text-faint);
}

.remove:hover:not(:disabled) {
  background: var(--danger-soft);
  color: var(--danger);
}

.none {
  padding: 1rem 0.8rem;
  font-size: 1.3rem;
  color: var(--text-faint);
}
</style>
