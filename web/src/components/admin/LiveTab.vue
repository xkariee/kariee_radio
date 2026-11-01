<script setup lang="ts">
import { computed, ref } from 'vue'
import type { AdminBroadcast } from '../../types'
import { store } from '../../store'
import { formatDistance } from '../../utils/format'
import Icon from '../Icon.vue'
import Cover from '../Cover.vue'

// Every radio playing on the server - who, what, where, how far, and who can hear it.
const { state } = store
const data = computed(() => state.admin.data!)

type Filter = 'all' | 'near' | 'dj' | 'radio' | 'radiocar'
const filter = ref<Filter>('all')
const q = ref('')

const filters: { id: Filter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'near', label: 'Near me' },
  { id: 'dj', label: 'DJ booths' },
  { id: 'radio', label: 'Personal' },
  { id: 'radiocar', label: 'Cars' },
]

const KIND: Record<AdminBroadcast['kind'], { icon: string; label: string }> = {
  dj: { icon: 'speaker', label: 'DJ booth' },
  radio: { icon: 'radio', label: 'Personal radio' },
  radiocar: { icon: 'car', label: 'Car radio' },
}

const list = computed(() => {
  const radius = data.value.nearbyRadius
  const needle = q.value.trim().toLowerCase()
  return data.value.broadcasts
    .filter((b) => {
      if (filter.value === 'near') return (b.distance ?? Infinity) <= radius
      if (filter.value !== 'all') return b.kind === filter.value
      return true
    })
    .filter(
      (b) =>
        !needle ||
        [b.song.title, b.song.artist, b.ownerName, b.label, b.street, b.zone, String(b.ownerId ?? '')]
          .filter(Boolean)
          .some((v) => String(v).toLowerCase().includes(needle)),
    )
    .sort((a, b) => (a.distance ?? Infinity) - (b.distance ?? Infinity))
})

// Progress keeps ticking between refreshes.
function progressOf(b: AdminBroadcast) {
  const extra = b.playing ? (state.now - state.admin.fetchedAt) / 1000 : 0
  return Math.min(b.song.duration || Infinity, b.progress + Math.max(0, extra))
}

const pct = (b: AdminBroadcast) => `${b.song.duration ? Math.min(100, (progressOf(b) / b.song.duration) * 100) : 0}%`

const canHear = (b: AdminBroadcast) => !!state.proximity[b.id]?.near

function ban(b: AdminBroadcast) {
  state.banDraft = { targetId: b.ownerId, identifier: b.ownerIdentifier, name: b.ownerName }
}

const isMe = (b: AdminBroadcast) => b.ownerId != null && b.ownerId === data.value.me
</script>

<template>
  <div>
    <div class="admin-toolbar">
      <label class="admin-search">
        <Icon name="search" :size="15" />
        <input v-model="q" type="text" placeholder="Song, player, ID or place" aria-label="Search live radios" @keydown.esc.stop.prevent="q = ''" />
      </label>
      <div class="admin-chips" role="group" aria-label="Filter radios">
        <button v-for="f in filters" :key="f.id" class="chip" :aria-pressed="filter === f.id" @click="filter = f.id">
          {{ f.label }}
        </button>
      </div>
      <span class="spacer" />
      <button class="btn btn-secondary sm" @click="store.adminStopNear()">
        <Icon name="target" :size="14" /> Stop near me
      </button>
      <button class="btn btn-danger sm" :disabled="!data.broadcasts.length" @click="store.adminStopAll()">
        <Icon name="stop" :size="13" /> Stop all
      </button>
    </div>

    <ul v-if="list.length" class="admin-list" role="list">
      <li v-for="b in list" :key="b.id" class="admin-row live-row" :class="{ paused: !b.playing }">
        <div class="art">
          <Cover :src="b.song.thumbnail ?? null" :hue="b.song.hue" :size="52" :radius="10" />
          <span class="state" :title="b.playing ? 'Playing' : 'Paused'">
            <span v-if="b.playing" class="eq live" aria-hidden="true"><i /><i /><i /></span>
            <Icon v-else name="pause" :size="11" />
            <span class="sr-only">{{ b.playing ? 'Playing' : 'Paused' }}</span>
          </span>
        </div>

        <div class="admin-cell">
          <span class="admin-strong truncate" :title="b.song.title">{{ b.song.title }}</span>
          <span class="admin-sub truncate">{{ b.song.artist }}</span>
          <span class="mini">
            <span class="mini-bar"><span :style="{ width: pct(b) }" /></span>
            <span class="admin-faint">{{ store.formatTime(progressOf(b)) }} / {{ store.formatTime(b.song.duration) }}</span>
          </span>
        </div>

        <div class="admin-cell">
          <span class="kind" :class="b.kind"><Icon :name="KIND[b.kind].icon" :size="13" /> {{ KIND[b.kind].label }}</span>
          <span v-if="b.kind === 'dj'" class="admin-sub truncate" :title="b.label">{{ b.label }}</span>
          <span class="admin-sub truncate">
            <Icon name="user" :size="12" class="inline" />
            {{ b.ownerName }}<span class="admin-faint"> · ID {{ b.ownerId ?? '?' }}</span>
            <span v-if="isMe(b)" class="admin-pill accent you">You</span>
          </span>
        </div>

        <div class="admin-cell">
          <span class="admin-sub truncate"><Icon name="map-pin" :size="12" class="inline" /> {{ b.street || 'Unknown street' }}</span>
          <span class="admin-faint truncate">{{ b.zone || '—' }} · {{ formatDistance(b.distance) }} away{{ b.interior ? ' · indoors' : '' }}</span>
          <span class="admin-pills">
            <span class="admin-pill" :title="`Players within ${data.nearbyRadius} m`"><Icon name="users" :size="11" /> {{ b.nearbyPlayers }} nearby</span>
            <span v-if="canHear(b)" class="admin-pill ok"><Icon name="headphones" :size="11" /> You can hear this</span>
            <span v-if="b.queueLength" class="admin-pill">{{ b.queueLength }} queued</span>
          </span>
        </div>

        <div class="admin-actions">
          <button class="icon-btn sm" :disabled="!b.coords" :aria-label="`Set waypoint to ${b.label}`" title="Set waypoint" @click="store.adminWaypoint(b.coords, b.street || b.label)">
            <Icon name="map-pin" :size="16" />
          </button>
          <button class="icon-btn sm" :disabled="!b.coords" :aria-label="`Teleport to ${b.label}`" title="Teleport there" @click="store.adminTeleport(b.coords)">
            <Icon name="navigation" :size="15" />
          </button>
          <button class="icon-btn sm danger" :aria-label="`Stop ${b.song.title}`" title="Stop this music" @click="store.adminStop(b)">
            <Icon name="stop" :size="14" />
          </button>
          <button
            class="icon-btn sm danger"
            :disabled="isMe(b) || !b.ownerIdentifier"
            :aria-label="`Ban ${b.ownerName} from the radio`"
            title="Ban this player"
            @click="ban(b)"
          >
            <Icon name="ban" :size="16" />
          </button>
        </div>
      </li>
    </ul>

    <div v-else class="empty-state admin-empty">
      <span class="badge"><Icon name="radio" :size="26" /></span>
      <h3>{{ data.broadcasts.length ? 'Nothing matches' : 'Nothing is playing right now' }}</h3>
      <p v-if="data.broadcasts.length">Try a different filter or search.</p>
      <p v-else>Radios, car radios and DJ booths show up here the moment someone presses play.</p>
    </div>
  </div>
</template>

<style scoped>
.live-row {
  grid-template-columns: 5.2rem minmax(0, 1.5fr) minmax(0, 1.3fr) minmax(0, 1.5fr) auto;
}

.live-row.paused .art {
  opacity: 0.6;
}

.art {
  position: relative;
}

.state {
  position: absolute;
  right: -0.5rem;
  bottom: -0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.2rem;
  height: 2.2rem;
  border-radius: 50%;
  background: var(--panel-raised);
  box-shadow: 0 0 0 0.2rem var(--panel-raised);
  color: var(--text-dim);
}

.state .eq {
  height: 0.9rem;
}

.mini {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  margin-top: 0.3rem;
}

.mini-bar {
  flex: 1;
  max-width: 14rem;
  height: 0.3rem;
  border-radius: var(--r-pill);
  background: var(--fill-3);
  overflow: hidden;
}

.mini-bar > span {
  display: block;
  height: 100%;
  background: var(--accent);
  transition: width 1s linear;
}

.kind {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1.15rem;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--text-dim);
}

.kind.dj {
  color: #c79bff;
}

.kind.radiocar {
  color: #7cc4ff;
}

.inline {
  display: inline-block;
  vertical-align: -0.1rem;
  margin-right: 0.2rem;
}

.you {
  margin-left: 0.4rem;
  height: 1.8rem;
}
</style>
