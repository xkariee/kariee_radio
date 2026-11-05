<script setup lang="ts">
import { computed } from 'vue'
import type { AdminTab } from '../../types'
import { store } from '../../store'
import { plural } from '../../utils/format'
import Icon from '../Icon.vue'
import LiveTab from '../admin/LiveTab.vue'
import BoothsTab from '../admin/BoothsTab.vue'
import BansTab from '../admin/BansTab.vue'
import ActivityTab from '../admin/ActivityTab.vue'

const { state } = store
const admin = computed(() => state.admin)
const data = computed(() => state.admin.data)

const stats = computed(() => {
  const d = data.value
  if (!d) return null
  const playing = d.broadcasts.filter((b) => b.playing).length
  const near = d.broadcasts.filter((b) => (b.distance ?? Infinity) <= d.nearbyRadius).length
  const liveBooths = d.stations.filter((s) => s.playing).length
  const onlineBans = d.bans.filter((b) => b.online).length
  return [
    { tab: 'live' as AdminTab, icon: 'radio', value: playing, label: 'Playing now', sub: `${plural(d.broadcasts.length, 'radio')} on` },
    { tab: 'live' as AdminTab, icon: 'target', value: near, label: 'Near you', sub: `within ${d.nearbyRadius} m` },
    { tab: 'booths' as AdminTab, icon: 'speaker', value: d.stations.length, label: 'DJ booths', sub: `${liveBooths} live` },
    { tab: 'bans' as AdminTab, icon: 'ban', value: d.bans.length, label: 'Active bans', sub: `${onlineBans} online now` },
  ]
})

const tabs = computed(() => {
  const d = data.value
  return [
    { id: 'live' as AdminTab, label: 'Live radios', icon: 'radio', count: d?.broadcasts.length },
    { id: 'booths' as AdminTab, label: 'DJ booths', icon: 'speaker', count: d?.stations.length },
    { id: 'bans' as AdminTab, label: 'Bans', icon: 'ban', count: d?.bans.length },
    { id: 'activity' as AdminTab, label: 'Activity', icon: 'activity', count: undefined },
  ]
})

function onTabKey(e: KeyboardEvent, i: number) {
  if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return
  e.preventDefault()
  e.stopPropagation()
  const next = (i + (e.key === 'ArrowRight' ? 1 : -1) + tabs.value.length) % tabs.value.length
  state.admin.tab = tabs.value[next].id
  ;((e.currentTarget as HTMLElement).parentElement?.children[next] as HTMLElement | undefined)?.focus()
}

const updated = computed(() => {
  if (!admin.value.fetchedAt) return 'Loading…'
  const s = Math.max(0, Math.round((state.now - admin.value.fetchedAt) / 1000))
  return s < 3 ? 'Live · just updated' : `Live · updated ${s}s ago`
})
</script>

<template>
  <div class="admin">
    <header class="head">
      <div>
        <p class="eyebrow kicker"><Icon name="shield" :size="13" /> Admin</p>
        <h1 class="view-title">Radio control</h1>
        <p class="sub">Every radio and DJ booth on the server, refreshed every few seconds.</p>
      </div>
      <div class="head-side">
        <span class="updated" :class="{ stale: !!admin.error }">
          <i aria-hidden="true" />{{ admin.error ? 'Connection lost' : updated }}
        </span>
        <button class="icon-btn" :class="{ spin: admin.loading }" aria-label="Refresh now" title="Refresh now" @click="store.fetchAdmin()">
          <Icon name="refresh" :size="17" />
        </button>
      </div>
    </header>

    <p v-if="admin.error && !data" class="admin-error" role="alert"><Icon name="alert" :size="16" /> {{ admin.error }}</p>

    <template v-if="data">
      <div class="stats">
        <button v-for="s in stats" :key="s.label" class="stat" @click="state.admin.tab = s.tab">
          <span class="stat-icon" aria-hidden="true"><Icon :name="s.icon" :size="17" /></span>
          <span class="stat-value">{{ s.value }}</span>
          <span class="stat-label">{{ s.label }}</span>
          <span class="stat-sub">{{ s.sub }}</span>
        </button>
      </div>

      <div class="tabs" role="tablist" aria-label="Admin sections">
        <button
          v-for="(t, i) in tabs"
          :id="`admin-tab-${t.id}`"
          :key="t.id"
          class="tab"
          role="tab"
          :aria-selected="state.admin.tab === t.id"
          :aria-controls="`admin-panel-${t.id}`"
          :tabindex="state.admin.tab === t.id ? 0 : -1"
          @click="state.admin.tab = t.id"
          @keydown="onTabKey($event, i)"
        >
          <Icon :name="t.icon" :size="15" />
          {{ t.label }}
          <span v-if="t.count != null" class="tab-count">{{ t.count }}</span>
        </button>
      </div>

      <section :id="`admin-panel-${state.admin.tab}`" role="tabpanel" :aria-labelledby="`admin-tab-${state.admin.tab}`" class="panel-body">
        <LiveTab v-if="state.admin.tab === 'live'" />
        <BoothsTab v-else-if="state.admin.tab === 'booths'" />
        <BansTab v-else-if="state.admin.tab === 'bans'" />
        <ActivityTab v-else />
      </section>
    </template>

    <div v-else-if="!admin.error" class="loading" aria-busy="true">
      <div class="stats">
        <span v-for="i in 4" :key="i" class="stat skeleton" style="height: 11rem" />
      </div>
      <span v-for="i in 4" :key="i" class="skeleton" style="height: 7.2rem; border-radius: 1.4rem" />
    </div>
  </div>
</template>

<style scoped>
.admin {
  display: flex;
  flex-direction: column;
  gap: 2rem;
  padding-top: 1.4rem;
}

.head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 2rem;
}

.kicker {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  color: var(--accent);
  margin-bottom: 0.4rem;
}

.sub {
  margin-top: 0.4rem;
  font-size: 1.35rem;
  color: var(--text-dim);
}

.head-side {
  display: flex;
  align-items: center;
  gap: 0.8rem;
}

.updated {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  font-size: 1.2rem;
  font-weight: 650;
  color: var(--text-dim);
}

.updated i {
  width: 0.8rem;
  height: 0.8rem;
  border-radius: 50%;
  background: var(--ok);
  box-shadow: 0 0 0 0.3rem rgba(98, 227, 166, 0.2);
}

.updated.stale i {
  background: var(--danger);
  box-shadow: 0 0 0 0.3rem var(--danger-soft);
}

.spin svg {
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.admin-error {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  padding: 1.4rem 1.6rem;
  border-radius: var(--r-lg);
  background: var(--danger-soft);
  color: var(--danger);
  font-weight: 600;
}

.stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 1.2rem;
}

.stat {
  position: relative;
  display: grid;
  grid-template-columns: 1fr auto;
  grid-template-rows: auto auto auto;
  align-items: center;
  gap: 0.2rem 1rem;
  padding: 1.6rem;
  border-radius: var(--r-lg);
  background: var(--fill-1);
  border: 0.1rem solid var(--line);
  text-align: left;
  transition:
    background-color 0.16s var(--ease),
    border-color 0.16s var(--ease);
}

.stat:hover {
  background: var(--fill-2);
  border-color: var(--line-2);
}

.stat-icon {
  grid-column: 2;
  grid-row: 1 / span 2;
  align-self: start;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3.6rem;
  height: 3.6rem;
  border-radius: 1.1rem;
  background: var(--accent-soft);
  color: var(--accent);
}

.stat-value {
  grid-column: 1;
  grid-row: 1;
  font-size: 3rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.1;
  color: var(--text-h);
  font-variant-numeric: tabular-nums;
}

.stat-label {
  grid-column: 1;
  grid-row: 2;
  font-size: 1.3rem;
  font-weight: 700;
  color: var(--text);
}

.stat-sub {
  grid-column: 1 / span 2;
  grid-row: 3;
  font-size: 1.15rem;
  color: var(--text-faint);
}

.tabs {
  display: flex;
  gap: 0.4rem;
  padding: 0.4rem;
  border-radius: var(--r-pill);
  background: var(--fill-1);
  border: 0.1rem solid var(--line);
  align-self: flex-start;
}

.tab {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  height: 3.6rem;
  padding: 0 1.5rem;
  border-radius: var(--r-pill);
  font-size: 1.3rem;
  font-weight: 700;
  color: var(--text-dim);
  transition:
    background-color 0.16s var(--ease),
    color 0.16s var(--ease);
}

.tab:hover {
  color: var(--text-h);
}

.tab[aria-selected='true'] {
  background: var(--fill-3);
  color: var(--text-h);
}

.tab[aria-selected='true'] svg {
  color: var(--accent);
}

.tab-count {
  min-width: 2.2rem;
  height: 2rem;
  padding: 0 0.6rem;
  border-radius: var(--r-pill);
  background: var(--fill-3);
  font-size: 1.1rem;
  font-variant-numeric: tabular-nums;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.tab[aria-selected='true'] .tab-count {
  background: var(--accent);
  color: var(--on-accent);
}

.loading {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
</style>

<style>
.admin-toolbar {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.8rem;
  margin-bottom: 1.4rem;
}

.admin-toolbar .spacer {
  flex: 1;
}

.admin-search {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  height: 3.6rem;
  width: 26rem;
  padding: 0 1.3rem;
  border-radius: var(--r-pill);
  background: var(--fill-2);
  border: 0.1rem solid var(--line);
  color: var(--text-faint);
  transition: border-color 0.16s var(--ease);
}

.admin-search:focus-within {
  border-color: var(--accent-line);
}

.admin-search input {
  flex: 1;
  min-width: 0;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-h);
  font-size: 1.3rem;
}

.admin-search input::placeholder {
  color: var(--text-faint);
}

.admin-chips {
  display: flex;
  gap: 0.5rem;
}

.admin-chips .chip {
  height: 3rem;
  padding: 0 1.2rem;
  font-size: 1.2rem;
}

.admin-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.admin-row {
  display: grid;
  align-items: center;
  gap: 1.6rem;
  padding: 1.1rem 1.2rem;
  border-radius: var(--r-lg);
  background: var(--fill-1);
  border: 0.1rem solid var(--line);
  transition:
    background-color 0.14s var(--ease),
    border-color 0.14s var(--ease);
}

.admin-row:hover {
  background: var(--fill-2);
}

.admin-cell {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.admin-strong {
  font-size: 1.4rem;
  font-weight: 700;
  color: var(--text-h);
}

.admin-sub {
  font-size: 1.2rem;
  color: var(--text-dim);
}

.admin-faint {
  font-size: 1.15rem;
  color: var(--text-faint);
}

.admin-actions {
  display: flex;
  align-items: center;
  gap: 0.2rem;
  justify-content: flex-end;
}

.admin-actions .icon-btn.danger:hover:not(:disabled) {
  background: var(--danger-soft);
  color: var(--danger);
}

.admin-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  height: 2.2rem;
  padding: 0 0.9rem;
  border-radius: var(--r-pill);
  background: var(--fill-2);
  font-size: 1.1rem;
  font-weight: 700;
  color: var(--text-dim);
  white-space: nowrap;
}

.admin-pill.accent {
  background: var(--accent-soft);
  color: var(--accent);
}

.admin-pill.ok {
  background: rgba(98, 227, 166, 0.12);
  color: var(--ok);
}

.admin-pill.danger {
  background: var(--danger-soft);
  color: var(--danger);
}

.admin-pill.warn {
  background: rgba(255, 196, 92, 0.12);
  color: #ffc65c;
}

.admin-pills {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin-top: 0.2rem;
}

.admin-cell > .admin-pill {
  align-self: flex-start;
}

.admin-empty {
  padding: 4rem 2rem;
}
</style>
