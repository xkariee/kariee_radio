import { computed } from 'vue'
import type { BroadcastKind, CreatorAccess, CreatorHud, DjAccessRule, LiveBroadcast } from '../types'
import * as audioEngine from '../services/audioEngine'
import { fetchNui, isNuiEnv, onNuiMessage } from '../services/nui'
import { settings } from '../settings'
import { asArray } from '../utils/format'
import { session, state } from './state'
import { playlistFromRow, songFromPayload, songFromRow, upsertSong } from './songs'
import { advance, bindBroadcast, currentSong, queueEntry, setSharedQueue, shared } from './player'
import { favoritesPlaylist } from './playlists'
import { isTempoPending } from './tempo'
import { setView } from './navigation'
import { toast } from './ui'

const DRIFT_TOLERANCE = 2
const SEEK_GRACE_MS = 3000
const CLOCK_INTERVAL_MS = 500

const DEFAULT_LABEL: Record<BroadcastKind, string> = { dj: 'DJ booth', radiocar: 'Car radio', radio: 'Personal radio' }

const knownVideo: Record<string, string> = {}
const knownPlaying: Record<string, boolean> = {}

export function liveProgress(broadcast: LiveBroadcast) {
  if (!broadcast.playing) return broadcast.progress
  const progress = broadcast.progress + (state.now - broadcast.syncedAt) / 1000
  return broadcast.song.duration ? Math.min(broadcast.song.duration, progress) : progress
}

export const widgetBroadcast = computed<LiveBroadcast | null>(() => {
  let best: LiveBroadcast | null = null
  let bestScore = -1
  for (const broadcast of Object.values(state.live)) {
    const proximity = state.proximity[broadcast.id]
    if (!proximity?.near) continue
    if (settings.widgetScope === 'dj' && broadcast.kind !== 'dj') continue
    if (broadcast.kind === 'radio' && state.serverId != null && broadcast.owner === state.serverId) continue
    const score = proximity.volume + (broadcast.playing ? 1 : 0)
    if (score > bestScore) {
      best = broadcast
      bestScore = score
    }
  }
  return best
})

export function closeAccessPicker(access: DjAccessRule[] | null) {
  state.creatorAccess = null
  fetchNui('creatorAccess', access ? { access } : {})
}

function resetPlayback() {
  state.queue = []
  state.queueCursor = 0
  state.progress = 0
  state.isPlaying = false
  state.tempo = null
}

async function hydrate() {
  if (!isNuiEnv) return
  const data = await fetchNui('getState')
  if (!data) return

  state.identifier = data.identifier
  state.myName = data.name

  const playlists = asArray<any>(data.playlists)
  const favorites = asArray<any>(data.favorites)
  const recent = asArray<any>(data.recent)
  for (const row of [...playlists.flatMap((playlist) => asArray(playlist.tracks)), ...favorites, ...recent]) {
    upsertSong(songFromRow(row))
  }

  state.playlists = [favoritesPlaylist(favorites.map((row) => row.song_id)), ...playlists.map(playlistFromRow)]
  state.recentlyPlayedIds = recent.map((row) => row.song_id)
  state.invites = asArray<any>(data.invites).map((row) => ({
    playlistId: row.playlist_id,
    name: row.name,
    hue: row.hue,
    invitedBy: row.invited_by,
    invitedByName: row.invited_by_name,
  }))
  state.isAdmin = !!data.isAdmin
  state.ban = data.ban ?? null
  state.djLocked = !!data.djLocked

  if (state.contextKind == null) return

  const broadcast = data.broadcast
  if (!broadcast) return resetPlayback()

  const song = songFromPayload(broadcast.song)
  if (shared.value) {
    setSharedQueue(song, asArray(broadcast.queue).map(songFromPayload))
  } else {
    upsertSong(song)
    if (currentSong.value?.id !== song.id) {
      state.queue = [queueEntry(song.id, 0)]
      state.queueCursor = 0
    }
  }
  state.progress = broadcast.progress || 0
  state.isPlaying = !!broadcast.playing
  state.volume = broadcast.volume ?? state.volume
  state.tempo = broadcast.tempo ?? null
}

function syncLive(incoming: Record<string, any>) {
  const live: Record<string, LiveBroadcast> = {}
  for (const [id, broadcast] of Object.entries(incoming)) {
    if (!broadcast.song?.videoId) continue
    live[id] = {
      id,
      kind: broadcast.kind,
      label: broadcast.label ?? DEFAULT_LABEL[broadcast.kind as BroadcastKind] ?? DEFAULT_LABEL.radio,
      owner: broadcast.owner,
      song: songFromPayload(broadcast.song),
      playing: !!broadcast.playing,
      progress: broadcast.progress || 0,
      syncedAt: Date.now(),
    }
  }
  state.live = live
  for (const id of Object.keys(state.proximity)) if (!(id in incoming)) delete state.proximity[id]
}

function dropMissingPlayers(incoming: Record<string, any>) {
  for (const id of Object.keys(knownVideo)) {
    if (id in incoming) continue
    audioEngine.destroy(id)
    delete knownVideo[id]
    delete knownPlaying[id]
    if (id === session.broadcastId) {
      state.isPlaying = false
      state.tempo = null
    }
  }
}

function syncPlayer(id: string, broadcast: any, progress: number, skipDriftCheck: boolean) {
  const videoId = broadcast.song.videoId
  if (knownVideo[id] !== videoId) {
    audioEngine.play(id, videoId, progress)
    knownVideo[id] = videoId
  } else {
    if (knownPlaying[id] !== broadcast.playing) {
      if (broadcast.playing) audioEngine.resume(id)
      else audioEngine.pause(id)
    }
    const position = skipDriftCheck ? null : audioEngine.getPosition(id)
    if (position && Math.abs(position.time - progress) > DRIFT_TOLERANCE) audioEngine.seek(id, progress)
  }
  knownPlaying[id] = broadcast.playing
}

function handleBroadcastSync(data: { broadcasts?: Record<string, any> }) {
  const incoming = data.broadcasts || {}
  syncLive(incoming)
  dropMissingPlayers(incoming)

  for (const [id, broadcast] of Object.entries(incoming)) {
    const videoId = broadcast.song?.videoId
    if (!videoId) continue
    const progress = broadcast.progress || 0
    const mine = id === session.broadcastId
    const pending = session.pendingSeek

    const seekInFlight = mine && pending != null && pending.videoId === videoId && Date.now() - pending.at < SEEK_GRACE_MS
    const racedSeek = seekInFlight && Math.abs(progress - pending!.to) > DRIFT_TOLERANCE
    if (mine && !racedSeek) session.pendingSeek = null

    syncPlayer(id, broadcast, progress, seekInFlight)
    if (!mine) continue

    state.isPlaying = broadcast.playing
    if (!racedSeek) state.progress = progress
    if (!isTempoPending()) state.tempo = broadcast.tempo ?? null
    if (shared.value) setSharedQueue(songFromPayload(broadcast.song), asArray(broadcast.queue).map(songFromPayload))
  }
}

function reportAudioClocks() {
  if (!state.lightsEnabled) return
  const clocks: Record<string, { time: number; playing: boolean; videoId: string }> = {}
  for (const [id, videoId] of Object.entries(knownVideo)) {
    if (!id.startsWith('dj:')) continue
    const position = audioEngine.getPosition(id)
    if (position) clocks[id] = { ...position, videoId }
  }
  if (Object.keys(clocks).length) fetchNui('audioClock', { clocks }).catch(() => {})
}

function normalizeCreator(data: any): CreatorHud {
  return {
    ...data,
    steps: asArray(data.steps),
    options: asArray(data.options),
    info: asArray(data.info),
    keys: asArray<any>(data.keys).map((key) => ({ ...key, keys: asArray(key.keys) })),
  }
}

function normalizeCreatorAccess(data: any): CreatorAccess {
  return {
    jobs: asArray<any>(data.jobs).map((job) => ({ name: job.name, label: job.label ?? job.name, grades: asArray(job.grades) })),
    access: asArray(data.access),
  }
}

export function bindNui() {
  if (!isNuiEnv) return

  setInterval(reportAudioClocks, CLOCK_INTERVAL_MS)

  fetchNui('getConfig')
    .then((config) => {
      if (!config) return
      state.widgetServerEnabled = config.widget !== false
      if (config.widgetCommand) state.widgetCommand = config.widgetCommand
      if (config.serverId != null) state.serverId = config.serverId
      state.lightsEnabled = !!config.lights
    })
    .catch(() => {})

  onNuiMessage('open', (data) => {
    const context = data.context
    state.visible = true
    bindBroadcast(context?.id ?? null, context?.kind ?? null)
    state.contextKind = context?.kind ?? null
    state.contextBlocked = context ? null : (data.blocked ?? null)
    state.djLocked = false
    if (session.broadcastId) {
      audioEngine.onEnded(session.broadcastId, () => {
        if (state.contextKind === 'radio') advance(true)
      })
    }
    if (data.view === 'admin') setView('admin')
    hydrate()
  })

  onNuiMessage('close', () => {
    state.visible = false
    state.menu = null
    state.popover = null
    state.widgetEditing = false
  })

  onNuiMessage('broadcastSync', handleBroadcastSync)

  onNuiMessage('volume', (data) => {
    audioEngine.setVolume(data.id, data.volume)
    state.proximity[data.id] = { near: data.near ?? data.volume > 0, volume: data.volume }
  })

  onNuiMessage('banned', (data) => {
    state.ban = data.ban ?? null
  })

  onNuiMessage('creator', (data) => {
    state.creator = data.data ? normalizeCreator(data.data) : null
  })

  onNuiMessage('creatorAccess', (data) => {
    state.creatorAccess = data.data ? normalizeCreatorAccess(data.data) : null
  })

  onNuiMessage('widgetToggle', () => {
    settings.widget = !settings.widget
    fetchNui('widgetToggled', { enabled: settings.widget })
  })

  onNuiMessage('inviteReceived', (data) => {
    state.invites.push(data.invite)
    toast(`${data.invite?.invitedByName ?? 'Someone'} invited you to “${data.invite?.name ?? 'a playlist'}”`, 'users')
  })
}
