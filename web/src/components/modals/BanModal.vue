<script setup lang="ts">
import { computed, ref } from 'vue'
import { store } from '../../store'
import { colorForId } from '../../utils/avatar'
import Modal from '../Modal.vue'
import Toggle from '../Toggle.vue'
import Icon from '../Icon.vue'

const { state } = store
const draft = state.banDraft ?? {}

const players = computed(() => (state.admin.data?.players ?? []).filter((p) => p.id !== state.admin.data?.me))
const existing = computed(() => state.admin.data?.bans.find((b) => b.identifier === (draft.identifier ?? '')))

type Target = { targetId?: number; identifier?: string; name?: string }
const selected = ref<Target | null>(draft.targetId != null || draft.identifier ? { ...draft } : null)
const mode = ref<'online' | 'offline'>('online')
const q = ref('')
const offlineId = ref('')
const offlineName = ref('')

const scope = ref<'dj' | 'all'>(existing.value?.scope ?? 'dj')
const durations = [
  { label: '1 hour', minutes: 60 },
  { label: '1 day', minutes: 1440 },
  { label: '1 week', minutes: 10080 },
  { label: '30 days', minutes: 43200 },
  { label: 'Permanent', minutes: null },
]
const minutes = ref<number | null>(1440)
const reason = ref(existing.value?.reason ?? '')
const quickReasons = ['Loud or distorted music', 'Spamming songs', 'Offensive content', 'Ignoring warnings']
const stopNow = ref(true)
const error = ref<string | null>(null)
const busy = ref(false)

const filtered = computed(() => {
  const needle = q.value.trim().toLowerCase()
  return players.value.filter((p) => !needle || p.name.toLowerCase().includes(needle) || String(p.id) === needle)
})

const target = computed<Target | null>(() => {
  if (selected.value) return selected.value
  if (mode.value === 'offline' && offlineId.value.trim()) {
    return { identifier: offlineId.value.trim(), name: offlineName.value.trim() || offlineId.value.trim() }
  }
  return null
})

async function submit() {
  if (!target.value || busy.value) return
  busy.value = true
  error.value = await store.adminBan({
    ...target.value,
    scope: scope.value,
    minutes: minutes.value,
    reason: reason.value.trim(),
    stopNow: stopNow.value,
  })
  busy.value = false
}

function close() {
  state.banDraft = null
}
</script>

<template>
  <Modal
    :title="existing ? 'Change ban' : 'Ban from radio'"
    subtitle="They’ll be told why when they try to play something."
    icon="ban"
    tone="danger"
    :width="540"
    @close="close"
  >
    <form id="ban-form" class="form" @submit.prevent="submit">
      <section aria-labelledby="ban-who">
        <h3 id="ban-who" class="eyebrow label">Player</h3>

        <div v-if="selected" class="chosen">
          <span class="avatar" :style="{ background: colorForId(selected.identifier ?? String(selected.targetId)) }" aria-hidden="true">
            {{ (selected.name || '?')[0] }}
          </span>
          <span class="chosen-text">
            <b>{{ selected.name || 'Unknown player' }}</b>
            <span>
              <template v-if="selected.targetId != null">ID {{ selected.targetId }} · online</template>
              <template v-else>offline</template>
              <template v-if="selected.identifier"> · {{ selected.identifier }}</template>
            </span>
          </span>
          <button type="button" class="btn btn-quiet sm" @click="selected = null">Change</button>
        </div>

        <template v-else>
          <div class="segmented" role="radiogroup" aria-label="Find player by">
            <button type="button" class="chip" role="radio" :aria-checked="mode === 'online'" @click="mode = 'online'">Online player</button>
            <button type="button" class="chip" role="radio" :aria-checked="mode === 'offline'" @click="mode = 'offline'">By identifier</button>
          </div>

          <template v-if="mode === 'online'">
            <label class="search">
              <Icon name="search" :size="15" />
              <input v-model="q" type="text" placeholder="Name or server ID" aria-label="Search online players" autofocus />
            </label>
            <ul class="people" role="listbox" aria-label="Online players">
              <li v-for="p in filtered" :key="p.id" role="option" :aria-selected="false">
                <button type="button" class="person" @click="selected = { targetId: p.id, identifier: p.identifier, name: p.name }">
                  <span class="avatar sm" :style="{ background: colorForId(p.identifier) }" aria-hidden="true">{{ p.name[0] }}</span>
                  <span class="p-name truncate">{{ p.name }}</span>
                  <span class="p-id">ID {{ p.id }}</span>
                </button>
              </li>
              <li v-if="!filtered.length" class="none">No one online matches.</li>
            </ul>
          </template>

          <div v-else class="offline">
            <label class="field">
              <span>Identifier</span>
              <input v-model="offlineId" class="text-input" placeholder="e.g. char1:abc123…" autofocus />
            </label>
            <label class="field">
              <span>Name <i>(optional)</i></span>
              <input v-model="offlineName" class="text-input" placeholder="Shown in the bans list" />
            </label>
          </div>
        </template>
      </section>

      <section aria-labelledby="ban-scope">
        <h3 id="ban-scope" class="eyebrow label">Ban from</h3>
        <div class="options" role="radiogroup" aria-labelledby="ban-scope">
          <button type="button" class="option" role="radio" :aria-checked="scope === 'dj'" @click="scope = 'dj'">
            <Icon name="speaker" :size="18" />
            <span><b>DJ booths only</b><span>They keep their own radio and car radio.</span></span>
          </button>
          <button type="button" class="option" role="radio" :aria-checked="scope === 'all'" @click="scope = 'all'">
            <Icon name="radio" :size="18" />
            <span><b>All radios</b><span>Personal, car and DJ booths.</span></span>
          </button>
        </div>
      </section>

      <section aria-labelledby="ban-length">
        <h3 id="ban-length" class="eyebrow label">For how long</h3>
        <div class="segmented wrap" role="radiogroup" aria-labelledby="ban-length">
          <button
            v-for="d in durations"
            :key="d.label"
            type="button"
            class="chip"
            role="radio"
            :aria-checked="minutes === d.minutes"
            @click="minutes = d.minutes"
          >
            {{ d.label }}
          </button>
        </div>
      </section>

      <section aria-labelledby="ban-reason">
        <h3 id="ban-reason" class="eyebrow label">Reason</h3>
        <input v-model="reason" class="text-input" maxlength="255" placeholder="Shown to the player" aria-labelledby="ban-reason" />
        <div class="quick">
          <button v-for="r in quickReasons" :key="r" type="button" class="chip sm" @click="reason = r">{{ r }}</button>
        </div>
      </section>

      <Toggle v-model="stopNow" icon="stop" label="Stop their music now" description="Ends anything they’re playing that this ban covers." />

      <p v-if="error" class="error" role="alert"><Icon name="alert" :size="15" /> {{ error }}</p>
    </form>

    <template #footer>
      <button type="button" class="btn btn-quiet" @click="close">Cancel</button>
      <button type="submit" form="ban-form" class="btn btn-danger-solid" :disabled="!target || busy">
        <Icon name="ban" :size="14" /> {{ existing ? 'Update ban' : 'Ban player' }}
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

.label {
  margin-bottom: 0.8rem;
}

.chosen {
  display: flex;
  align-items: center;
  gap: 1.2rem;
  padding: 1rem 1rem 1rem 1.2rem;
  border-radius: var(--r-lg);
  background: var(--fill-2);
  border: 0.1rem solid var(--line-2);
}

.chosen-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  font-size: 1.2rem;
  color: var(--text-dim);
}

.chosen-text b {
  font-size: 1.45rem;
  color: var(--text-h);
}

.chosen-text span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.avatar {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 4rem;
  height: 4rem;
  border-radius: 50%;
  flex-shrink: 0;
  font-size: 1.5rem;
  font-weight: 800;
  color: rgba(0, 0, 0, 0.62);
}

.avatar.sm {
  width: 3.2rem;
  height: 3.2rem;
  font-size: 1.25rem;
}

.segmented {
  display: flex;
  gap: 0.6rem;
  margin-bottom: 1rem;
}

.segmented.wrap {
  flex-wrap: wrap;
  margin-bottom: 0;
}

.search {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  height: 4rem;
  padding: 0 1.3rem;
  border-radius: var(--r-pill);
  background: var(--fill-2);
  border: 0.1rem solid var(--line-2);
  color: var(--text-faint);
}

.search:focus-within {
  border-color: var(--accent-line);
}

.search input {
  flex: 1;
  min-width: 0;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-h);
  font-size: 1.35rem;
}

.people {
  list-style: none;
  margin: 0.8rem 0 0;
  padding: 0;
  max-height: 19rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.person {
  display: flex;
  align-items: center;
  gap: 1rem;
  width: 100%;
  padding: 0.6rem 0.8rem;
  border-radius: var(--r-md);
  text-align: left;
}

.person:hover {
  background: var(--fill-2);
}

.p-name {
  flex: 1;
  min-width: 0;
  font-size: 1.35rem;
  font-weight: 650;
  color: var(--text-h);
}

.p-id {
  font-size: 1.15rem;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
}

.none {
  padding: 1rem 0.8rem;
  font-size: 1.3rem;
  color: var(--text-faint);
}

.offline {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--text-dim);
}

.field i {
  font-weight: 400;
  color: var(--text-faint);
}

.options {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.8rem;
}

.option {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
  padding: 1.2rem;
  border-radius: var(--r-lg);
  background: var(--fill-1);
  border: 0.15rem solid var(--line);
  text-align: left;
  color: var(--text-dim);
  transition:
    border-color 0.15s var(--ease),
    background-color 0.15s var(--ease);
}

.option:hover {
  background: var(--fill-2);
}

.option > span {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  font-size: 1.2rem;
}

.option b {
  font-size: 1.35rem;
  color: var(--text-h);
}

.option[aria-checked='true'] {
  border-color: var(--danger);
  background: var(--danger-soft);
}

.option[aria-checked='true'] > svg {
  color: var(--danger);
}

.chip[aria-checked='true'] {
  background: var(--text-h);
  border-color: var(--text-h);
  color: #17141b;
}

.quick {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.8rem;
}

.chip.sm {
  height: 2.8rem;
  padding: 0 1.1rem;
  font-size: 1.15rem;
}

.error {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  font-size: 1.3rem;
  font-weight: 600;
  color: var(--danger);
}
</style>
