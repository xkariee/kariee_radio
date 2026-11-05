<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import type { AdminStation } from '../../types'
import { store } from '../../store'
import { byDistance, formatDistance, matchesQuery, plural, shortDate } from '../../utils/format'
import Icon from '../Icon.vue'
import Cover from '../Cover.vue'

const { state } = store
const data = computed(() => state.admin.data!)

type Filter = 'all' | 'live' | 'idle'
const filter = ref<Filter>('all')
const q = ref('')

const filters: { id: Filter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'live', label: 'Live' },
  { id: 'idle', label: 'Idle' },
]

const CONSOLE: Record<string, string> = { prop: 'Prop', entity: 'Object', zone: 'Box' }

const list = computed(() =>
  data.value.stations
    .filter((s) => filter.value === 'all' || s.playing === (filter.value === 'live'))
    .filter((s) => matchesQuery(q.value, [s.label, s.ownerName, s.street, s.zone, `#${s.id}`, s.song?.title]))
    .sort(byDistance),
)

const editingId = ref<number | null>(null)
const draft = ref('')
const input = ref<HTMLInputElement[] | null>(null)

async function startRename(s: AdminStation) {
  editingId.value = s.id
  draft.value = s.label
  await nextTick()
  input.value?.[0]?.focus()
  input.value?.[0]?.select()
}

function commit(s: AdminStation) {
  if (editingId.value !== s.id) return
  editingId.value = null
  store.adminRenameStation(s, draft.value)
}

function cancel() {
  editingId.value = null
}

const broadcastFor = (s: AdminStation) => data.value.broadcasts.find((b) => b.id === s.broadcastId)

function soundLabel(s: AdminStation) {
  const setup = s.setup
  if (!setup || setup.audio === 'auto') return s.interior ? 'Whole interior' : 'Radius'
  if (setup.audio === 'interior') return setup.muffled ? `Interior · ${Math.round(setup.muffled)} m muffled` : 'Interior only'
  if (setup.audio === 'area') return `Area · ${setup.areaPoints} corners`
  return `Radius ${Math.round(setup.range ?? 0)} m`
}
</script>

<template>
  <div>
    <div class="admin-toolbar">
      <label class="admin-search">
        <Icon name="search" :size="15" />
        <input v-model="q" type="text" placeholder="Booth, owner or place" aria-label="Search DJ booths" @keydown.esc.stop.prevent="q = ''" />
      </label>
      <div class="admin-chips" role="group" aria-label="Filter booths">
        <button v-for="f in filters" :key="f.id" class="chip" :aria-pressed="filter === f.id" @click="filter = f.id">
          {{ f.label }}
        </button>
      </div>
      <span class="spacer" />
      <button class="btn btn-primary sm" @click="store.adminPlaceStation()">
        <Icon name="plus" :size="14" /> Place new booth
      </button>
    </div>

    <ul v-if="list.length" class="admin-list" role="list">
      <li v-for="s in list" :key="s.id" class="admin-row booth-row" :class="{ live: s.playing }">
        <span class="booth-icon" aria-hidden="true" :style="{ '--h': (s.id * 67) % 360 }">
          <Icon name="speaker" :size="20" />
          <span v-if="s.playing" class="live-dot" />
        </span>

        <div class="admin-cell">
          <form v-if="editingId === s.id" class="rename" @submit.prevent="commit(s)">
            <input
              ref="input"
              v-model="draft"
              class="text-input"
              maxlength="64"
              :aria-label="`New name for ${s.label}`"
              @keydown.esc.stop.prevent="cancel"
              @blur="commit(s)"
            />
          </form>
          <span v-else class="admin-strong truncate" :title="s.label">{{ s.label }}</span>
          <span class="admin-faint">
            #{{ s.id }} · {{ s.interior ? 'Indoors' : 'Outdoors' }} · placed {{ shortDate(s.createdAt) }}
          </span>
          <span class="admin-pills">
            <span class="admin-pill" title="How players open the booth">{{ CONSOLE[s.setup?.mode ?? 'prop'] }}</span>
            <span class="admin-pill" title="Who hears it"><Icon name="volume-2" :size="11" /> {{ soundLabel(s) }}</span>
            <span v-if="s.setup?.lights" class="admin-pill accent"><Icon name="sparkles" :size="11" /> {{ s.setup.lights }} lights</span>
            <span v-if="s.setup?.access?.length" class="admin-pill" :title="`Only usable by: ${s.setup.access.join(', ')}`">
              <Icon name="lock" :size="11" /> {{ plural(s.setup.access.length, 'job') }}
            </span>
          </span>
        </div>

        <div class="admin-cell">
          <span class="admin-sub truncate"><Icon name="user" :size="12" class="inline" /> {{ s.ownerName }}</span>
          <span class="admin-faint truncate" :title="s.ownerIdentifier">{{ s.ownerIdentifier }}</span>
        </div>

        <div class="admin-cell">
          <span class="admin-sub truncate"><Icon name="map-pin" :size="12" class="inline" /> {{ s.street || 'Unknown street' }}</span>
          <span class="admin-faint truncate">{{ s.zone || '—' }} · {{ formatDistance(s.distance) }} away</span>
        </div>

        <div class="admin-cell status">
          <template v-if="s.song && broadcastFor(s)">
            <span class="now">
              <Cover :src="s.song.thumbnail ?? null" :hue="s.song.hue" :size="30" :radius="6" />
              <span class="admin-cell">
                <span class="admin-sub truncate now-title">{{ s.song.title }}</span>
                <span class="admin-faint truncate">by {{ broadcastFor(s)?.ownerName }}</span>
              </span>
            </span>
            <span class="admin-pills">
              <span class="admin-pill" :class="s.playing ? 'ok' : 'warn'">{{ s.playing ? 'Live' : 'Paused' }}</span>
              <span class="admin-pill"><Icon name="users" :size="11" /> {{ broadcastFor(s)?.nearbyPlayers ?? 0 }} nearby</span>
            </span>
          </template>
          <span v-else class="admin-pill">Idle</span>
        </div>

        <div class="admin-actions">
          <button class="icon-btn sm" :aria-label="`Set waypoint to ${s.label}`" title="Set waypoint" @click="store.adminWaypoint(s.coords, s.label)">
            <Icon name="map-pin" :size="16" />
          </button>
          <button class="icon-btn sm" :aria-label="`Teleport to ${s.label}`" title="Teleport there" @click="store.adminTeleport(s.coords)">
            <Icon name="navigation" :size="15" />
          </button>
          <button class="icon-btn sm" :aria-label="`Rename ${s.label}`" title="Rename" @click="startRename(s)">
            <Icon name="edit-2" :size="14" />
          </button>
          <button
            class="icon-btn sm"
            :aria-label="`Edit setup of ${s.label}`"
            title="Edit setup (console, sound area, lights)"
            @click="store.adminEditStation(s)"
          >
            <Icon name="sparkles" :size="15" />
          </button>
          <button
            class="icon-btn sm danger"
            :disabled="!broadcastFor(s)"
            :aria-label="`Stop music at ${s.label}`"
            title="Stop the music here"
            @click="store.adminStop(broadcastFor(s)!)"
          >
            <Icon name="stop" :size="14" />
          </button>
          <button class="icon-btn sm danger" :aria-label="`Remove ${s.label}`" title="Remove booth" @click="store.adminRemoveStation(s)">
            <Icon name="trash-2" :size="15" />
          </button>
        </div>
      </li>
    </ul>

    <div v-else class="empty-state admin-empty">
      <span class="badge"><Icon name="speaker" :size="26" /></span>
      <h3>{{ data.stations.length ? 'No booths match' : 'No DJ booths yet' }}</h3>
      <p v-if="!data.stations.length">Place one where you’re standing. You’ll get the same placement tool as /createdj.</p>
      <button v-if="!data.stations.length" class="btn btn-primary" @click="store.adminPlaceStation()">
        <Icon name="plus" :size="14" /> Place new booth
      </button>
    </div>
  </div>
</template>

<style scoped>
.booth-row {
  grid-template-columns: 4.6rem minmax(0, 1.4fr) minmax(0, 1fr) minmax(0, 1.2fr) minmax(0, 1.4fr) auto;
}

.booth-icon {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 4.6rem;
  height: 4.6rem;
  border-radius: 1.2rem;
  background: linear-gradient(145deg, hsl(var(--h), 55%, 38%), hsl(calc(var(--h) + 40), 50%, 18%));
  color: rgba(255, 255, 255, 0.85);
}

.live-dot {
  position: absolute;
  top: -0.3rem;
  right: -0.3rem;
  width: 1.2rem;
  height: 1.2rem;
  border-radius: 50%;
  background: var(--ok);
  box-shadow: 0 0 0 0.25rem var(--panel);
}

.rename .text-input {
  height: 3.2rem;
  font-size: 1.35rem;
}

.now {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  min-width: 0;
}

.now-title {
  color: var(--text-h);
  font-weight: 650;
}

.inline {
  display: inline-block;
  vertical-align: -0.1rem;
  margin-right: 0.2rem;
}
</style>
