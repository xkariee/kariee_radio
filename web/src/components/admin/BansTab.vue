<script setup lang="ts">
import { computed, ref } from 'vue'
import type { AdminBan } from '../../types'
import { store } from '../../store'
import { colorForId } from '../../utils/avatar'
import { relativeTime, shortDate, toMs } from '../../utils/format'
import Icon from '../Icon.vue'

const { state } = store
const data = computed(() => state.admin.data!)
const q = ref('')

const list = computed(() => {
  const needle = q.value.trim().toLowerCase()
  return [...data.value.bans]
    .filter((b) => !needle || [b.name, b.identifier, b.reason, b.bannedBy].some((v) => v?.toLowerCase().includes(needle)))
    .sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0))
})

function expires(b: AdminBan) {
  if (!b.expiresAt) return 'Permanent'
  return `Ends ${relativeTime(b.expiresAt, state.now)}`
}

// Rough "how much is left" bar for timed bans.
function remainingPct(b: AdminBan) {
  const end = toMs(b.expiresAt)
  const start = toMs(b.createdAt)
  if (!end || !start || end <= start) return null
  return `${Math.max(0, Math.min(100, ((end - state.now) / (end - start)) * 100))}%`
}

function edit(b: AdminBan) {
  const online = data.value.players.find((p) => p.identifier === b.identifier)
  state.banDraft = { targetId: online?.id, identifier: b.identifier, name: b.name }
}
</script>

<template>
  <div>
    <div class="admin-toolbar">
      <label class="admin-search">
        <Icon name="search" :size="15" />
        <input v-model="q" type="text" placeholder="Name, identifier or reason" aria-label="Search bans" @keydown.esc.stop.prevent="q = ''" />
      </label>
      <span class="spacer" />
      <button class="btn btn-danger-solid sm" @click="state.banDraft = {}">
        <Icon name="ban" :size="14" /> Ban a player
      </button>
    </div>

    <ul v-if="list.length" class="admin-list" role="list">
      <li v-for="b in list" :key="b.identifier" class="admin-row ban-row">
        <span class="avatar" :style="{ background: colorForId(b.identifier) }" aria-hidden="true">
          {{ (b.name || '?')[0] }}
          <span v-if="b.online" class="online" title="Online now" />
        </span>

        <div class="admin-cell">
          <span class="admin-strong truncate">{{ b.name || 'Unknown player' }}</span>
          <span class="admin-faint truncate mono" :title="b.identifier">{{ b.identifier }}</span>
        </div>

        <div class="admin-cell">
          <span class="admin-pills">
            <span class="admin-pill" :class="b.scope === 'all' ? 'danger' : 'warn'">
              <Icon :name="b.scope === 'all' ? 'radio' : 'speaker'" :size="11" />
              {{ b.scope === 'all' ? 'All radios' : 'DJ booths' }}
            </span>
            <span v-if="b.online" class="admin-pill ok">Online</span>
          </span>
          <span class="admin-sub reason" :title="b.reason">{{ b.reason || 'No reason given' }}</span>
        </div>

        <div class="admin-cell">
          <span class="admin-sub">{{ expires(b) }}</span>
          <span v-if="remainingPct(b)" class="left"><span :style="{ width: remainingPct(b)! }" /></span>
          <span class="admin-faint">by {{ b.bannedBy || 'admin' }} · {{ shortDate(b.createdAt) }}</span>
        </div>

        <div class="admin-actions">
          <button class="btn btn-quiet sm" :aria-label="`Change ban for ${b.name}`" @click="edit(b)">
            <Icon name="edit-2" :size="13" /> Change
          </button>
          <button class="btn btn-secondary sm" :aria-label="`Unban ${b.name}`" @click="store.adminUnban(b)">
            <Icon name="unlock" :size="13" /> Unban
          </button>
        </div>
      </li>
    </ul>

    <div v-else class="empty-state admin-empty">
      <span class="badge"><Icon name="shield" :size="26" /></span>
      <h3>{{ data.bans.length ? 'No bans match' : 'No one is banned' }}</h3>
      <p v-if="!data.bans.length">
        Ban someone from DJ booths only, or from every radio, for a set time or for good. You can also ban straight
        from the Live radios and Activity tabs.
      </p>
    </div>
  </div>
</template>

<style scoped>
.ban-row {
  grid-template-columns: 4.2rem minmax(0, 1.2fr) minmax(0, 1.6fr) minmax(0, 1.1fr) auto;
}

.avatar {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 4.2rem;
  height: 4.2rem;
  border-radius: 50%;
  font-size: 1.6rem;
  font-weight: 800;
  color: rgba(0, 0, 0, 0.62);
}

.online {
  position: absolute;
  right: 0;
  bottom: 0;
  width: 1.2rem;
  height: 1.2rem;
  border-radius: 50%;
  background: var(--ok);
  box-shadow: 0 0 0 0.25rem var(--panel);
}

.mono {
  font-variant-numeric: tabular-nums;
  letter-spacing: 0.02em;
}

.reason {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.left {
  display: block;
  height: 0.3rem;
  max-width: 14rem;
  border-radius: var(--r-pill);
  background: var(--fill-3);
  overflow: hidden;
}

.left > span {
  display: block;
  height: 100%;
  background: var(--danger);
}
</style>
