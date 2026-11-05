import { watch } from 'vue'
import type { AdminBan, AdminBroadcast, AdminData, AdminStation, Coords, Song } from '../types'
import { fetchNui } from '../services/nui'
import { asArray, plural } from '../utils/format'
import { state } from './state'
import { songFromPayload } from './songs'
import { askConfirm, toast } from './ui'

const REFRESH_MS = 4000
const DEFAULT_RADIUS = 50

const BAN_ERRORS: Record<string, string> = {
  self: 'You can’t ban yourself.',
  no_player: 'That player couldn’t be found.',
  no_permission: 'You don’t have permission to ban.',
}

export interface BanPayload {
  targetId?: number
  identifier?: string
  name?: string
  scope: 'dj' | 'all'
  minutes: number | null
  reason: string
  stopNow: boolean
}

let refreshTimer: ReturnType<typeof setInterval> | null = null

const where = (spot: { street?: string | null; label?: string }) => spot.street || spot.label || 'that spot'
const songOrNull = (payload: any): Song | null => (payload?.songId ? songFromPayload(payload) : null)

function normalize(data: any): AdminData {
  return {
    now: data.now ?? Math.floor(Date.now() / 1000),
    me: data.me,
    nearbyRadius: data.nearbyRadius ?? DEFAULT_RADIUS,
    broadcasts: asArray<any>(data.broadcasts)
      .map((b) => ({ ...b, song: songOrNull(b.song) }))
      .filter((b) => b.song) as AdminBroadcast[],
    stations: asArray<any>(data.stations).map((s) => ({ ...s, song: songOrNull(s.song) })) as AdminStation[],
    bans: asArray<AdminBan>(data.bans),
    players: asArray(data.players),
    activity: asArray(data.activity),
  }
}

export async function fetchAdmin(silent = false) {
  if (!silent) state.admin.loading = true
  try {
    const data = await fetchNui('adminGetData')
    if (!data) {
      state.admin.error = 'You don’t have access to the admin panel.'
      state.isAdmin = false
      return
    }
    state.admin.data = normalize(data)
    state.admin.error = null
    state.admin.fetchedAt = Date.now()
  } catch {
    state.admin.error = 'Couldn’t load admin data. Retrying…'
  } finally {
    state.admin.loading = false
  }
}

const refresh = () => fetchAdmin(true)

export async function adminStop(broadcast: AdminBroadcast) {
  if (await fetchNui('adminStop', { id: broadcast.id })) toast(`Stopped “${broadcast.song.title}” on ${broadcast.label}`, 'stop')
  refresh()
}

export function adminStopNear() {
  const radius = state.admin.data?.nearbyRadius ?? DEFAULT_RADIUS
  askConfirm({
    title: 'Stop music near you?',
    message: `Every radio and DJ booth within ${radius} m of you will stop playing. Their owners get a notification.`,
    confirmLabel: 'Stop nearby music',
    tone: 'danger',
    icon: 'stop',
    onConfirm: async () => {
      const stopped = await fetchNui<number>('adminStopNear', { radius })
      toast(stopped ? `Stopped ${plural(stopped, 'radio')} near you` : 'Nothing was playing near you', 'stop')
      refresh()
    },
  })
}

export function adminStopAll() {
  const count = state.admin.data?.broadcasts.length ?? 0
  askConfirm({
    title: 'Stop all music?',
    message: `This stops all ${plural(count, 'radio')} on the server, including every DJ booth. Use it for emergencies or server events.`,
    confirmLabel: 'Stop everything',
    tone: 'danger',
    icon: 'stop',
    onConfirm: async () => {
      const stopped = await fetchNui<number>('adminStopAll')
      toast(`Stopped ${plural(stopped ?? 0, 'radio')}`, 'stop', 'danger')
      refresh()
    },
  })
}

export async function adminWaypoint(coords: Coords | null | undefined, label: string) {
  if (coords && (await fetchNui('adminWaypoint', { coords }))) toast(`Waypoint set: ${label}`, 'map-pin')
}

export function adminTeleport(coords: Coords | null | undefined) {
  if (coords) fetchNui('adminTeleport', { coords })
}

export async function adminRenameStation(station: AdminStation, label: string) {
  const clean = label.trim().slice(0, 64)
  if (!clean || clean === station.label) return
  if (await fetchNui('adminRenameStation', { id: station.id, label: clean })) {
    station.label = clean
    toast(`Renamed booth to “${clean}”`, 'edit-2')
  }
  refresh()
}

export function adminRemoveStation(station: AdminStation) {
  askConfirm({
    title: `Remove “${station.label}”?`,
    message: `The booth at ${where(station)} disappears for everyone${station.playing ? ' and its music stops' : ''}. This can’t be undone.`,
    confirmLabel: 'Remove booth',
    tone: 'danger',
    icon: 'trash-2',
    onConfirm: async () => {
      if (await fetchNui('adminRemoveStation', { id: station.id })) toast(`Removed “${station.label}”`, 'trash-2', 'danger')
      refresh()
    },
  })
}

export function adminEditStation(station: AdminStation) {
  fetchNui('adminEditStation', { id: station.id })
}

export function adminPlaceStation() {
  fetchNui('adminPlaceStation')
}

export async function adminBan(payload: BanPayload): Promise<string | null> {
  const res = await fetchNui<{ ok: boolean; err?: string; stopped?: number }>('adminBan', payload)
  if (!res?.ok) return BAN_ERRORS[res?.err ?? ''] ?? 'The ban didn’t go through. Try again.'

  const target = payload.scope === 'all' ? 'all radios' : 'DJ booths'
  const stopped = res.stopped ? ` · stopped ${plural(res.stopped, 'radio')}` : ''
  toast(`${payload.name ?? 'Player'} banned from ${target}${stopped}`, 'ban', 'danger')
  state.banDraft = null
  refresh()
  return null
}

export async function adminUnban(ban: AdminBan) {
  if (await fetchNui('adminUnban', { identifier: ban.identifier })) toast(`Unbanned ${ban.name || ban.identifier}`, 'unlock')
  refresh()
}

watch(
  () => state.visible && state.view === 'admin' && state.isAdmin,
  (open) => {
    if (refreshTimer) clearInterval(refreshTimer)
    refreshTimer = null
    if (!open) return
    fetchAdmin()
    refreshTimer = setInterval(refresh, REFRESH_MS)
  },
  { immediate: true },
)
