<script setup lang="ts">
import { computed, ref } from 'vue'
import type { AdminActivity } from '../../types'
import { store } from '../../store'
import { clockTime, relativeTime } from '../../utils/format'
import Icon from '../Icon.vue'

// Recent plays, admin actions, bans and booth changes - newest first. Answers "who played that?".
const { state } = store
const data = computed(() => state.admin.data!)

type Filter = 'all' | 'plays' | 'admin' | 'bans' | 'booths'
const filter = ref<Filter>('all')
const q = ref('')

const GROUP: Record<string, Filter> = {
  play: 'plays',
  admin_stop: 'admin',
  admin_stop_all: 'admin',
  admin_stop_near: 'admin',
  ban: 'bans',
  unban: 'bans',
  booth_created: 'booths',
  booth_removed: 'booths',
  booth_renamed: 'booths',
}

const META: Record<string, { icon: string; verb: string; tone: string }> = {
  play: { icon: 'play', verb: 'played', tone: 'play' },
  admin_stop: { icon: 'stop', verb: 'stopped music', tone: 'admin' },
  admin_stop_all: { icon: 'stop', verb: 'stopped all music', tone: 'danger' },
  admin_stop_near: { icon: 'target', verb: 'stopped nearby music', tone: 'admin' },
  ban: { icon: 'ban', verb: 'banned someone', tone: 'danger' },
  unban: { icon: 'unlock', verb: 'lifted a ban', tone: 'admin' },
  booth_created: { icon: 'plus', verb: 'placed a booth', tone: 'booth' },
  booth_removed: { icon: 'trash-2', verb: 'removed a booth', tone: 'danger' },
  booth_renamed: { icon: 'edit-2', verb: 'renamed a booth', tone: 'booth' },
}

const meta = (a: AdminActivity) => META[a.action] ?? { icon: 'activity', verb: a.action, tone: 'admin' }

const list = computed(() => {
  const needle = q.value.trim().toLowerCase()
  return data.value.activity
    .filter((a) => filter.value === 'all' || GROUP[a.action] === filter.value)
    .filter(
      (a) =>
        !needle ||
        [a.actor, a.detail, a.label, a.target, String(a.actorId ?? '')].filter(Boolean).some((v) => String(v).toLowerCase().includes(needle)),
    )
})

const filters: { id: Filter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'plays', label: 'Plays' },
  { id: 'admin', label: 'Admin actions' },
  { id: 'bans', label: 'Bans' },
  { id: 'booths', label: 'Booths' },
]

const isOnline = (a: AdminActivity) => a.actorId != null && data.value.players.some((p) => p.id === a.actorId)
const canBan = (a: AdminActivity) => a.action === 'play' && !!a.identifier && a.actorId !== data.value.me

function ban(a: AdminActivity) {
  state.banDraft = { targetId: isOnline(a) ? a.actorId : undefined, identifier: a.identifier, name: a.actor }
}

function copyLink(a: AdminActivity) {
  if (a.videoId) store.copyLink({ id: a.videoId, title: '', artist: '', duration: 0, hue: 0, videoId: a.videoId })
}
</script>

<template>
  <div>
    <div class="admin-toolbar">
      <label class="admin-search">
        <Icon name="search" :size="15" />
        <input v-model="q" type="text" placeholder="Player, song or ID" aria-label="Search activity" @keydown.esc.stop.prevent="q = ''" />
      </label>
      <div class="admin-chips" role="group" aria-label="Filter activity">
        <button v-for="f in filters" :key="f.id" class="chip" :aria-pressed="filter === f.id" @click="filter = f.id">
          {{ f.label }}
        </button>
      </div>
    </div>

    <ol v-if="list.length" class="timeline">
      <li v-for="(a, i) in list" :key="`${a.t}-${i}`" class="event">
        <span class="when">
          <span class="clock">{{ clockTime(a.t) }}</span>
          <span class="admin-faint">{{ relativeTime(a.t, state.now) }}</span>
        </span>
        <span class="dot" :class="meta(a).tone" aria-hidden="true"><Icon :name="meta(a).icon" :size="13" /></span>
        <span class="admin-cell text">
          <span class="line">
            <b>{{ a.actor }}</b>
            <span v-if="a.actorId != null" class="admin-faint"> · ID {{ a.actorId }}</span>
            <span v-if="isOnline(a)" class="admin-pill ok online">Online</span>
          </span>
          <span class="admin-sub">
            <template v-if="a.action === 'play'">played {{ a.detail }}<template v-if="a.label"> on <b>{{ a.label }}</b></template></template>
            <template v-else>{{ a.detail }}</template>
          </span>
        </span>
        <span class="admin-actions">
          <button v-if="a.videoId" class="icon-btn sm" aria-label="Copy YouTube link" title="Copy YouTube link" @click="copyLink(a)">
            <Icon name="link" :size="15" />
          </button>
          <button v-if="canBan(a)" class="btn btn-quiet sm ban" :aria-label="`Ban ${a.actor}`" @click="ban(a)">
            <Icon name="ban" :size="13" /> Ban
          </button>
        </span>
      </li>
    </ol>

    <div v-else class="empty-state admin-empty">
      <span class="badge"><Icon name="activity" :size="26" /></span>
      <h3>{{ data.activity.length ? 'Nothing matches' : 'No activity yet' }}</h3>
      <p v-if="!data.activity.length">Plays, admin actions, bans and booth changes since the last restart show up here.</p>
    </div>
  </div>
</template>

<style scoped>
.timeline {
  position: relative;
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
}

.event {
  position: relative;
  display: grid;
  grid-template-columns: 8.4rem 3.2rem minmax(0, 1fr) auto;
  align-items: center;
  gap: 1.4rem;
  padding: 0.9rem 1rem;
  border-radius: var(--r-md);
  transition: background-color 0.14s var(--ease);
}

.event:hover {
  background: var(--fill-1);
}

/* the timeline rail running through the dots */
.event::before {
  content: '';
  position: absolute;
  left: calc(1rem + 8.4rem + 1.4rem + 1.6rem);
  top: 0;
  bottom: 0;
  width: 0.2rem;
  margin-left: -0.1rem;
  background: var(--line);
}

.event:first-child::before {
  top: 50%;
}

.event:last-child::before {
  bottom: 50%;
}

.when {
  display: flex;
  flex-direction: column;
  text-align: right;
}

.clock {
  font-size: 1.3rem;
  font-weight: 700;
  color: var(--text);
  font-variant-numeric: tabular-nums;
}

.dot {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3.2rem;
  height: 3.2rem;
  border-radius: 50%;
  background: var(--fill-3);
  color: var(--text-dim);
  box-shadow: 0 0 0 0.4rem var(--panel);
}

.dot.play {
  background: var(--accent-soft);
  color: var(--accent);
}

.dot.danger {
  background: var(--danger-soft);
  color: var(--danger);
}

.dot.booth {
  background: rgba(199, 155, 255, 0.14);
  color: #c79bff;
}

.text b {
  color: var(--text-h);
  font-weight: 700;
}

.line {
  font-size: 1.35rem;
}

.online {
  margin-left: 0.6rem;
  height: 1.8rem;
}

.ban:hover {
  color: var(--danger);
  background: var(--danger-soft);
}
</style>
