import { computed, reactive, watch } from 'vue'
import type {
  AdminBan,
  AdminBroadcast,
  AdminData,
  AdminStation,
  AdminTab,
  BanDraft,
  BroadcastKind,
  ConfirmState,
  CreatorHud,
  Coords,
  Invite,
  LiveBroadcast,
  MenuAnchor,
  MenuState,
  Nav,
  OnlineCandidate,
  Playlist,
  PlayingFrom,
  Proximity,
  QueueEntry,
  RadioBan,
  RepeatMode,
  Song,
  Toast,
  ViewKind,
} from './types'
import {
  currentUser,
  devLiveBroadcast,
  invites as mockInvites,
  playlists as mockPlaylists,
  recentlyPlayedIds as mockRecent,
  songs as mockSongs,
} from './data/mock'
import { fetchVideoById, parseYouTubeId, searchYouTube, youtubeConfigured } from './services/youtube'
import * as audioEngine from './services/audioEngine'
import { fetchNui, isNuiEnv, onNuiMessage } from './services/nui'
import { loadJson, loadList, saveJson } from './utils/persist'
import { asArray } from './utils/format'
import { settings } from './settings'

type PlaylistId = string | number
type Popover = 'sleep' | null

interface State {
  songs: Song[]
  playlists: Playlist[]
  queue: QueueEntry[]
  queueCursor: number
  isPlaying: boolean
  progress: number
  volume: number
  muted: boolean
  shuffle: boolean
  repeat: RepeatMode
  view: ViewKind
  activePlaylistId: PlaylistId | null
  history: Nav[]
  historyIndex: number
  recentlyPlayedIds: string[]
  playingFrom: PlayingFrom | null
  searchQuery: string
  searching: boolean
  searchError: string | null
  searchResultIds: string[]
  recentSearches: string[]
  libraryFilter: 'all' | 'mine' | 'shared'
  menu: MenuState | null
  popover: Popover
  createPlaylistOpen: boolean
  editPlaylistId: PlaylistId | null
  inviteePlaylistId: PlaylistId | null
  deletePlaylistId: PlaylistId | null
  settingsOpen: boolean
  shortcutsOpen: boolean
  invites: Invite[]
  candidates: OnlineCandidate[]
  candidateSearching: boolean
  identifier: string
  myName: string
  contextKind: BroadcastKind | null
  sleepEndsAt: number | null
  sleepEndOfTrack: boolean
  now: number
  toasts: Toast[]
  // Bumped to ask the top bar's search input to take focus (shortcut / nav item).
  focusSearchSignal: number
  visible: boolean
  // ─── nearby / bans / admin ───
  serverId: number | null
  isAdmin: boolean
  ban: RadioBan | null
  // every broadcast on the server, and whether we're in range of each
  live: Record<string, LiveBroadcast>
  proximity: Record<string, Proximity>
  widgetServerEnabled: boolean
  widgetCommand: string
  widgetEditing: boolean
  admin: {
    data: AdminData | null
    loading: boolean
    error: string | null
    tab: AdminTab
    fetchedAt: number
  }
  confirm: ConfirmState | null
  banDraft: BanDraft | null
  // DJ booth creator HUD (client/creator.lua), null when not creating
  creator: CreatorHud | null
}

const playerPrefs = loadJson('player', { shuffle: false, repeat: 'off' as RepeatMode })

const state = reactive<State>({
  songs: isNuiEnv ? [] : [...mockSongs],
  playlists: isNuiEnv ? [] : [...mockPlaylists],
  queue: [],
  queueCursor: 0,
  isPlaying: false,
  progress: 0,
  volume: 68,
  muted: false,
  shuffle: playerPrefs.shuffle,
  repeat: playerPrefs.repeat,
  view: 'home',
  activePlaylistId: null,
  history: [{ view: 'home', playlistId: null }],
  historyIndex: 0,
  recentlyPlayedIds: isNuiEnv ? [] : [...mockRecent],
  playingFrom: null,
  searchQuery: '',
  searching: false,
  searchError: null,
  searchResultIds: [],
  recentSearches: loadList('recentSearches'),
  libraryFilter: 'all',
  menu: null,
  popover: null,
  createPlaylistOpen: false,
  editPlaylistId: null,
  inviteePlaylistId: null,
  deletePlaylistId: null,
  settingsOpen: false,
  shortcutsOpen: false,
  invites: isNuiEnv ? [] : [...mockInvites],
  candidates: [],
  candidateSearching: false,
  identifier: currentUser.identifier,
  myName: currentUser.name,
  contextKind: isNuiEnv ? null : 'radio',
  sleepEndsAt: null,
  sleepEndOfTrack: false,
  now: Date.now(),
  toasts: [],
  focusSearchSignal: 0,
  visible: !isNuiEnv,
  serverId: isNuiEnv ? null : 7,
  isAdmin: !isNuiEnv,
  ban: null,
  live: isNuiEnv ? {} : { [devLiveBroadcast.id]: { ...devLiveBroadcast, syncedAt: Date.now() } },
  proximity: isNuiEnv ? {} : { [devLiveBroadcast.id]: { near: true, volume: 0.8 } },
  widgetServerEnabled: true,
  widgetCommand: 'radiohud',
  widgetEditing: false,
  admin: { data: null, loading: false, error: null, tab: 'live', fetchedAt: 0 },
  confirm: null,
  banDraft: null,
  creator: null,
})

watch(
  () => [state.shuffle, state.repeat],
  () => saveJson('player', { shuffle: state.shuffle, repeat: state.repeat }),
)

let myBroadcastId: string | null = isNuiEnv ? null : 'radio:dev'
// DJ stations and car radios are collaborative (shared, server-side queue); personal radio keeps
// its queue purely local. state.contextKind tracks which kind the open NUI session is bound to.
const isShared = () => state.contextKind === 'dj' || state.contextKind === 'radiocar'

let qidSeq = 1000
const nextQid = () => `q${qidSeq++}`

function songById(id: string | undefined) {
  return id ? state.songs.find((s) => s.id === id) : undefined
}

function upsertSong(song: Song) {
  const idx = state.songs.findIndex((s) => s.id === song.id)
  if (idx === -1) state.songs.push(song)
  else state.songs[idx] = song
}

function toClientSong(row: any): Song {
  return {
    id: row.song_id,
    title: row.title,
    artist: row.artist,
    duration: row.duration,
    hue: row.hue,
    videoId: row.video_id,
    thumbnail: row.thumbnail ?? null,
  }
}

// Broadcast payloads carry songs in the camelCase shape server/main.lua's SerializeSong produces,
// distinct from the raw snake_case DB rows toClientSong handles.
function songFromBroadcast(s: any): Song {
  return {
    id: s.songId,
    title: s.title,
    artist: s.artist,
    duration: s.duration,
    hue: s.hue,
    videoId: s.videoId,
    thumbnail: s.thumbnail ?? null,
  }
}

function toClientPlaylist(row: any): Playlist {
  return {
    id: row.id,
    name: row.name,
    cover: row.cover ?? null,
    hue: row.hue,
    isDefault: !!row.is_default,
    ownerIdentifier: row.owner_identifier,
    ownerName: row.owner_name ?? row.owner_identifier,
    collaborators: asArray<any>(row.collaborators).map((c: any) => ({ identifier: c.identifier, name: c.name ?? c.identifier })),
    songIds: asArray<any>(row.tracks).map((t: any) => t.song_id),
  }
}

const currentEntry = computed(() => state.queue[state.queueCursor])
const currentSong = computed(() => songById(currentEntry.value?.songId))

const upNext = computed(() => state.queue.slice(state.queueCursor + 1))

const activePlaylist = computed(() =>
  state.activePlaylistId != null ? state.playlists.find((p) => p.id === state.activePlaylistId) ?? null : null,
)

const activePlaylistSongs = computed(() => {
  const pl = activePlaylist.value
  if (!pl) return []
  return pl.songIds.map(songById).filter((s): s is Song => !!s)
})

const recentlyPlayed = computed(() => state.recentlyPlayedIds.map(songById).filter((s): s is Song => !!s))

const searchResults = computed(() => state.searchResultIds.map(songById).filter((s): s is Song => !!s))

const shared = computed(() => state.contextKind === 'dj' || state.contextKind === 'radiocar')

const anyModalOpen = computed(
  () =>
    state.createPlaylistOpen ||
    state.editPlaylistId != null ||
    state.inviteePlaylistId != null ||
    state.deletePlaylistId != null ||
    state.settingsOpen ||
    state.shortcutsOpen ||
    state.confirm != null ||
    state.banDraft != null,
)

const sleepRemaining = computed(() =>
  state.sleepEndsAt ? Math.max(0, Math.round((state.sleepEndsAt - state.now) / 1000)) : null,
)

// ─── Bans / nearby widget ──────────────────────────────────────────────────

// The player's ban, if it covers the radio they have open right now.
const activeBan = computed<RadioBan | null>(() => {
  const ban = state.ban
  if (!ban) return null
  if (ban.expires_at && ban.expires_at * 1000 <= state.now) return null
  if (ban.scope === 'all' || state.contextKind === 'dj') return ban
  return null
})

// Stops an action before it reaches the server with a reason the player can act on (the server
// rejects it regardless).
function playBlocked(): boolean {
  if (isNuiEnv && state.contextKind == null) {
    toast('Open your radio (or a DJ booth) to play music', 'radio')
    return true
  }
  if (activeBan.value) {
    toast(activeBan.value.scope === 'all' ? 'You’re banned from using the radio' : 'You’re banned from DJ booths', 'ban', 'danger')
    return true
  }
  return false
}

function liveProgress(b: LiveBroadcast) {
  if (!b.playing) return b.progress
  const p = b.progress + (state.now - b.syncedAt) / 1000
  return b.song.duration ? Math.min(b.song.duration, p) : p
}

// What the nearby widget shows: the loudest broadcast we're in range of (playing beats paused),
// DJ booths only unless the player chose "all radios". Never your own personal radio.
const widgetBroadcast = computed<LiveBroadcast | null>(() => {
  let best: LiveBroadcast | null = null
  let bestScore = -1
  for (const b of Object.values(state.live)) {
    const p = state.proximity[b.id]
    if (!p?.near) continue
    if (settings.widgetScope === 'dj' && b.kind !== 'dj') continue
    if (b.kind === 'radio' && state.serverId != null && b.owner === state.serverId) continue
    const score = p.volume + (b.playing ? 1 : 0)
    if (score > bestScore) {
      best = b
      bestScore = score
    }
  }
  return best
})

function startWidgetEditing() {
  state.settingsOpen = false
  state.menu = null
  state.widgetEditing = true
}

function finishWidgetEditing(reopenSettings = true) {
  state.widgetEditing = false
  if (reopenSettings) state.settingsOpen = true
}

function askConfirm(c: Omit<ConfirmState, 'tone' | 'icon'> & Partial<Pick<ConfirmState, 'tone' | 'icon'>>) {
  state.confirm = { tone: 'default', icon: 'alert', ...c }
}

function formatTime(sec: number): string {
  const total = Math.max(0, Math.floor(sec))
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  return h ? `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}` : `${m}:${s.toString().padStart(2, '0')}`
}

function formatLength(sec: number): string {
  const mins = Math.round(sec / 60)
  if (mins < 60) return `${mins} min`
  const h = Math.floor(mins / 60)
  const m = mins % 60
  return m ? `${h} hr ${m} min` : `${h} hr`
}

function shuffled<T>(list: T[]): T[] {
  const a = [...list]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

// ─── Toasts ────────────────────────────────────────────────────────────────

let toastSeq = 0
function toast(text: string, icon = 'check', tone: Toast['tone'] = 'default') {
  const id = ++toastSeq
  state.toasts = [...state.toasts.slice(-2), { id, text, icon, tone }]
  setTimeout(() => dismissToast(id), 2800)
}

function dismissToast(id: number) {
  state.toasts = state.toasts.filter((t) => t.id !== id)
}

// ─── Playback ──────────────────────────────────────────────────────────────

const effectiveVolume = () => (state.muted ? 0 : state.volume)

// Ticks the displayed progress bar between authoritative server syncs, and drives the sleep timer.
setInterval(() => {
  state.now = Date.now()
  if (state.sleepEndsAt && state.now >= state.sleepEndsAt) fireSleepTimer()

  if (!state.isPlaying) return
  const song = currentSong.value
  if (!song) return
  if (state.progress < song.duration) state.progress += 1
  // No audio engine outside the game - fake the "ended" event so queue/repeat can be exercised.
  else if (!isNuiEnv) advance(true)
}, 1000)

function recordRecentlyPlayed(id: string) {
  state.recentlyPlayedIds = [id, ...state.recentlyPlayedIds.filter((x) => x !== id)].slice(0, 30)
}

function syncCurrentPlayback() {
  state.progress = 0
  const song = currentSong.value
  if (!song) {
    state.isPlaying = false
    return
  }
  recordRecentlyPlayed(song.id)
  state.isPlaying = true
  fetchNui('play', { song, volume: effectiveVolume() })
}

function playSong(song: Song, context?: Song[], from: PlayingFrom | null = null) {
  if (playBlocked()) return
  state.playingFrom = from
  const list = context && context.length ? context : [song]
  const idx = Math.max(
    0,
    list.findIndex((s) => s.id === song.id),
  )

  if (isShared()) {
    const rest = state.shuffle ? shuffled(list.filter((_, i) => i !== idx)) : list.slice(idx + 1)
    recordRecentlyPlayed(song.id)
    fetchNui('play', { song, volume: effectiveVolume(), queue: rest })
    return
  }

  if (state.shuffle) {
    const others = shuffled(list.map((s, i) => ({ s, i })).filter((x) => x.i !== idx))
    state.queue = [
      { qid: nextQid(), songId: song.id, order: idx },
      ...others.map((x) => ({ qid: nextQid(), songId: x.s.id, order: x.i })),
    ]
    state.queueCursor = 0
  } else {
    state.queue = list.map((s, i) => ({ qid: nextQid(), songId: s.id, order: i }))
    state.queueCursor = idx
  }
  syncCurrentPlayback()
}

function playList(list: Song[], from: PlayingFrom | null, opts: { shuffle?: boolean } = {}) {
  if (!list.length) return
  if (opts.shuffle !== undefined) state.shuffle = opts.shuffle
  const start = state.shuffle ? list[Math.floor(Math.random() * list.length)] : list[0]
  playSong(start, list, from)
}

function togglePlay() {
  const song = currentSong.value
  if (!song || playBlocked()) return
  state.isPlaying = !state.isPlaying
  fetchNui('togglePlay', {})
}

// `auto` = the song actually finished (vs. the user pressing next), which is the only time
// repeat-one and the end-of-track sleep timer apply.
function advance(auto = false) {
  if (auto && state.sleepEndOfTrack) {
    state.sleepEndOfTrack = false
    stopPlayback()
    toast('Sleep timer ended. Playback stopped.', 'moon')
    return
  }
  if (auto && state.repeat === 'one') {
    syncCurrentPlayback()
    return
  }
  if (state.queueCursor < state.queue.length - 1) {
    state.queueCursor += 1
    syncCurrentPlayback()
  } else if (state.repeat === 'all' && state.queue.length) {
    state.queueCursor = 0
    syncCurrentPlayback()
  } else {
    stopPlayback()
  }
}

function stopPlayback() {
  state.isPlaying = false
  state.progress = 0
  fetchNui('stop', {})
}

function next() {
  if (isShared()) {
    fetchNui('next', {})
    return
  }
  advance()
}

function prev() {
  if (state.progress > 4 && currentSong.value) {
    seek(0)
    return
  }
  if (!isShared() && state.queueCursor > 0) {
    state.queueCursor -= 1
    syncCurrentPlayback()
  } else {
    seek(0)
  }
}

function seek(sec: number) {
  const song = currentSong.value
  if (!song) return
  const clamped = Math.min(Math.max(0, sec), song.duration || sec)
  state.progress = clamped
  fetchNui('seek', { seconds: clamped })
}

function seekBy(delta: number) {
  seek(state.progress + delta)
}

function setVolume(v: number) {
  state.volume = Math.round(Math.min(100, Math.max(0, v)))
  if (state.volume > 0) state.muted = false
  fetchNui('setVolume', { volume: effectiveVolume() })
}

function toggleMute() {
  state.muted = !state.muted
  fetchNui('setVolume', { volume: effectiveVolume() })
}

function toggleShuffle(announce = false) {
  state.shuffle = !state.shuffle
  // Personal radio: reshuffle (or restore) what's coming up. Shared radios keep the queue as the
  // group built it - shuffle there only affects how the next list starts playing.
  if (!isShared()) {
    const head = state.queue.slice(0, state.queueCursor + 1)
    const upcoming = state.queue.slice(state.queueCursor + 1)
    state.queue = [...head, ...(state.shuffle ? shuffled(upcoming) : [...upcoming].sort((a, b) => a.order - b.order))]
  }
  if (announce) toast(state.shuffle ? 'Shuffle on' : 'Shuffle off', 'shuffle')
}

function cycleRepeat(announce = false) {
  if (isShared()) return
  state.repeat = state.repeat === 'off' ? 'all' : state.repeat === 'all' ? 'one' : 'off'
  if (announce) {
    const label = { off: 'Repeat off', all: 'Repeating queue', one: 'Repeating this song' }[state.repeat]
    toast(label, state.repeat === 'one' ? 'repeat-1' : 'repeat')
  }
}

// ─── Queue ─────────────────────────────────────────────────────────────────

function addToQueue(song: Song) {
  if (playBlocked()) return
  if (isShared()) fetchNui('enqueue', { song })
  else state.queue.push({ qid: nextQid(), songId: song.id, order: 1e6 + qidSeq })
  toast(`Added “${song.title}” to queue`, 'list-plus')
}

function addAllToQueue(list: Song[], label: string) {
  if (!list.length || playBlocked()) return
  if (isShared()) for (const song of list) fetchNui('enqueue', { song })
  else for (const song of list) state.queue.push({ qid: nextQid(), songId: song.id, order: 1e6 + qidSeq })
  toast(`Added ${list.length} songs from ${label} to queue`, 'list-plus')
}

function playNext(song: Song) {
  if (playBlocked()) return
  if (isShared()) fetchNui('enqueueNext', { song })
  else {
    const order = (currentEntry.value?.order ?? 0) + 0.5
    state.queue.splice(state.queueCursor + 1, 0, { qid: nextQid(), songId: song.id, order })
  }
  toast(`“${song.title}” will play next`, 'skip-forward')
}

function removeFromQueue(qid: string) {
  const idx = state.queue.findIndex((e) => e.qid === qid)
  if (idx === -1) return

  if (isShared()) {
    if (idx === 0) return // index 0 is the currently-playing song, not a removable queue entry
    fetchNui('removeFromQueue', { index: idx - 1 })
    return
  }

  if (idx < state.queueCursor) state.queueCursor -= 1
  state.queue.splice(idx, 1)
}

// Shared radios: replace the whole server-side "up next" list in one go (reorder / shuffle / clear).
function setUpNext(entries: QueueEntry[]) {
  if (isShared()) {
    const songs = entries.map((e) => songById(e.songId)).filter((s): s is Song => !!s)
    state.queue = [...state.queue.slice(0, 1), ...entries]
    fetchNui('setQueue', { queue: songs })
    return
  }
  state.queue = [...state.queue.slice(0, state.queueCursor + 1), ...entries]
}

function reorderUpNext(from: number, to: number) {
  const up = [...upNext.value]
  if (from === to || from < 0 || to < 0 || from >= up.length || to >= up.length) return
  const [entry] = up.splice(from, 1)
  up.splice(to, 0, entry)
  setUpNext(up)
}

function shuffleUpNext() {
  if (upNext.value.length < 2) return
  setUpNext(shuffled(upNext.value))
  toast('Shuffled up next', 'shuffle')
}

function clearUpNext() {
  if (!upNext.value.length) return
  setUpNext([])
  toast('Cleared up next', 'trash-2')
}

function jumpTo(qid: string) {
  const idx = state.queue.findIndex((e) => e.qid === qid)
  const song = songById(state.queue[idx]?.songId)
  if (idx === -1 || !song || playBlocked()) return

  if (isShared()) {
    const rest = state.queue
      .slice(idx + 1)
      .map((e) => songById(e.songId))
      .filter((s): s is Song => !!s)
    recordRecentlyPlayed(song.id)
    fetchNui('play', { song, volume: effectiveVolume(), queue: rest })
    return
  }
  state.queueCursor = idx
  syncCurrentPlayback()
}

// ─── Sleep timer ───────────────────────────────────────────────────────────

function setSleepTimer(option: number | 'end' | null) {
  state.popover = null
  state.sleepEndsAt = typeof option === 'number' ? Date.now() + option * 60_000 : null
  state.sleepEndOfTrack = option === 'end'
  if (option === null) toast('Sleep timer off', 'moon')
  else if (option === 'end') toast('Playback will stop after this song', 'moon')
  else toast(`Sleep timer set for ${option < 60 ? `${option} min` : `${option / 60} hr`}`, 'moon')
}

function fireSleepTimer() {
  state.sleepEndsAt = null
  if (state.isPlaying) togglePlay()
  toast('Sleep timer ended. Playback paused.', 'moon')
}

// Shared radios advance server-side, so "end of track" is noticed by the song changing.
watch(
  () => currentSong.value?.id,
  (id, prevId) => {
    if (state.sleepEndOfTrack && isShared() && prevId && id !== prevId) {
      state.sleepEndOfTrack = false
      if (state.isPlaying) togglePlay()
      toast('Sleep timer ended. Playback paused.', 'moon')
    }
  },
)

// ─── Navigation ────────────────────────────────────────────────────────────

function applyNav(nav: Nav) {
  state.view = nav.view
  state.activePlaylistId = nav.playlistId
  state.menu = null
}

function setView(view: ViewKind, playlistId: PlaylistId | null = null) {
  const cur = state.history[state.historyIndex]
  if (!cur || cur.view !== view || cur.playlistId !== playlistId) {
    state.history = [...state.history.slice(0, state.historyIndex + 1), { view, playlistId }].slice(-40)
    state.historyIndex = state.history.length - 1
  }
  applyNav({ view, playlistId })
}

function goBack() {
  if (state.historyIndex <= 0) return
  state.historyIndex -= 1
  applyNav(state.history[state.historyIndex])
}

function goForward() {
  if (state.historyIndex >= state.history.length - 1) return
  state.historyIndex += 1
  applyNav(state.history[state.historyIndex])
}

function openSearch(query?: string) {
  if (query !== undefined) state.searchQuery = query
  if (state.view !== 'search') setView('search')
  state.focusSearchSignal++
}

// ─── Playlists ─────────────────────────────────────────────────────────────

function playlistById(id: PlaylistId) {
  return state.playlists.find((p) => p.id === id)
}

function playlistSongs(id: PlaylistId) {
  return (playlistById(id)?.songIds ?? []).map(songById).filter((s): s is Song => !!s)
}

async function createPlaylist(name: string, cover: string | null) {
  const row = await fetchNui<any>('createPlaylist', { name, cover })
  if (!row) return null
  const pl = toClientPlaylist(row)
  state.playlists.push(pl)
  state.createPlaylistOpen = false
  setView('playlist', pl.id)
  toast(`Created “${pl.name}”`, 'plus')
  return pl
}

function dropPlaylistLocally(id: PlaylistId) {
  state.playlists = state.playlists.filter((p) => p.id !== id)
  if (state.editPlaylistId === id) state.editPlaylistId = null
  if (state.inviteePlaylistId === id) state.inviteePlaylistId = null

  // Drop it from back/forward history too, so nothing navigates into a ghost.
  const before = state.history.slice(0, state.historyIndex + 1).filter((n) => n.playlistId !== id).length
  state.history = state.history.filter((n) => n.playlistId !== id)
  if (!state.history.length) state.history = [{ view: 'home', playlistId: null }]
  state.historyIndex = Math.max(0, Math.min(before - 1, state.history.length - 1))
  if (state.activePlaylistId === id) applyNav(state.history[state.historyIndex])
}

// Rename / cover / invite / delete are owner-only server-side; collaborators can only leave.
function isOwnerOf(pl: Playlist) {
  return !pl.isDefault && pl.ownerIdentifier === state.identifier
}

function deletePlaylist(id: PlaylistId) {
  const pl = playlistById(id)
  if (!pl || !isOwnerOf(pl)) return
  dropPlaylistLocally(id)
  fetchNui('deletePlaylist', { id })
  toast(`Deleted “${pl.name}”`, 'trash-2', 'danger')
}

function leavePlaylist(id: PlaylistId) {
  const pl = playlistById(id)
  if (!pl || pl.isDefault || isOwnerOf(pl)) return
  dropPlaylistLocally(id)
  fetchNui('removeCollaborator', { playlistId: id, identifier: state.identifier })
  toast(`Left “${pl.name}”`, 'x')
}

function requestDeletePlaylist(id: PlaylistId) {
  const pl = playlistById(id)
  if (!pl || !isOwnerOf(pl)) return
  state.editPlaylistId = null
  state.deletePlaylistId = id
}

function cancelDeletePlaylist() {
  state.deletePlaylistId = null
}

function confirmDeletePlaylist() {
  if (state.deletePlaylistId != null) deletePlaylist(state.deletePlaylistId)
  state.deletePlaylistId = null
}

function renamePlaylist(id: PlaylistId, name: string) {
  const pl = playlistById(id)
  if (pl && !pl.isDefault && name.trim() && name.trim() !== pl.name) {
    pl.name = name.trim()
    fetchNui('renamePlaylist', { id, name: pl.name })
  }
}

function setPlaylistCover(id: PlaylistId, cover: string | null) {
  const pl = playlistById(id)
  if (pl && !pl.isDefault && cover !== pl.cover) {
    pl.cover = cover
    fetchNui('setPlaylistCover', { id, cover })
  }
}

function isInPlaylist(playlistId: PlaylistId, songId: string) {
  return playlistById(playlistId)?.songIds.includes(songId) ?? false
}

function toggleSongInPlaylist(playlistId: PlaylistId, songId: string) {
  const pl = playlistById(playlistId)
  if (!pl) return
  const idx = pl.songIds.indexOf(songId)
  const adding = idx === -1
  if (adding) pl.songIds.push(songId)
  else pl.songIds.splice(idx, 1)

  if (playlistId === 'favorites') fetchNui('toggleFavorite', { song: songById(songId) })
  else if (adding) fetchNui('addTrack', { playlistId, song: songById(songId) })
  else fetchNui('removeTrack', { playlistId, songId })

  if (playlistId === 'favorites') toast(adding ? 'Added to Liked Songs' : 'Removed from Liked Songs', 'heart', 'like')
  else toast(adding ? `Added to ${pl.name}` : `Removed from ${pl.name}`, adding ? 'check' : 'x')
}

function removeSongFromPlaylist(playlistId: PlaylistId, songId: string) {
  if (isInPlaylist(playlistId, songId)) toggleSongInPlaylist(playlistId, songId)
}

function isFavorite(songId: string) {
  return isInPlaylist('favorites', songId)
}

function toggleFavorite(songId: string) {
  toggleSongInPlaylist('favorites', songId)
}

function isShareable(pl: Playlist) {
  return pl.collaborators.length > 0 || pl.ownerIdentifier !== state.identifier
}

async function inviteUser(playlistId: PlaylistId, target: OnlineCandidate) {
  await fetchNui('invite', { playlistId, targetId: target.id })
  toast(`Invite sent to ${target.name}`, 'user-plus')
}

function removeCollaborator(playlistId: PlaylistId, identifier: string) {
  const pl = playlistById(playlistId)
  if (!pl) return
  pl.collaborators = pl.collaborators.filter((c) => c.identifier !== identifier)
  fetchNui('removeCollaborator', { playlistId, identifier })
}

async function acceptInvite(playlistId: PlaylistId) {
  const invite = state.invites.find((i) => i.playlistId === playlistId)
  const row = await fetchNui<any>('acceptInvite', { playlistId })
  state.invites = state.invites.filter((i) => i.playlistId !== playlistId)
  if (row) {
    for (const t of asArray<any>(row.tracks)) upsertSong(toClientSong(t))
    if (!state.playlists.some((p) => p.id === row.id)) state.playlists.push(toClientPlaylist(row))
  }
  if (invite) toast(`Joined “${invite.name}”`, 'users')
}

function declineInvite(playlistId: PlaylistId) {
  state.invites = state.invites.filter((i) => i.playlistId !== playlistId)
  fetchNui('declineInvite', { playlistId })
}

let candidateTimer: ReturnType<typeof setTimeout> | null = null
function searchCandidates(query: string) {
  if (candidateTimer) clearTimeout(candidateTimer)
  state.candidateSearching = true
  candidateTimer = setTimeout(async () => {
    state.candidates = (await fetchNui<OnlineCandidate[]>('searchPlayers', { query })) ?? []
    state.candidateSearching = false
  }, 250)
}

// ─── Menus, layers ─────────────────────────────────────────────────────────

function openTrackMenu(trackId: string, anchor: MenuAnchor, contextPlaylistId?: PlaylistId) {
  state.popover = null
  state.menu = { kind: 'track', trackId, contextPlaylistId, ...anchor }
}

function openPlaylistMenu(playlistId: PlaylistId, anchor: MenuAnchor) {
  state.popover = null
  state.menu = { kind: 'playlist', playlistId, ...anchor }
}

function closeMenu() {
  state.menu = null
}

// ─── Admin panel ───────────────────────────────────────────────────────────

function normalizeAdmin(d: any): AdminData {
  const song = (s: any): Song | null => (s && s.songId ? songFromBroadcast(s) : null)
  return {
    now: d.now ?? Math.floor(Date.now() / 1000),
    me: d.me,
    nearbyRadius: d.nearbyRadius ?? 50,
    broadcasts: asArray<any>(d.broadcasts)
      .map((b) => ({ ...b, song: song(b.song) }))
      .filter((b) => b.song) as AdminBroadcast[],
    stations: asArray<any>(d.stations).map((s) => ({ ...s, song: song(s.song) })) as AdminStation[],
    bans: asArray<AdminBan>(d.bans),
    players: asArray(d.players),
    activity: asArray(d.activity),
  }
}

async function fetchAdmin(silent = false) {
  if (!silent) state.admin.loading = true
  try {
    const d = await fetchNui<any>('adminGetData', {})
    if (!d) {
      state.admin.error = 'You don’t have access to the admin panel.'
      state.isAdmin = false
      return
    }
    state.admin.data = normalizeAdmin(d)
    state.admin.error = null
    state.admin.fetchedAt = Date.now()
  } catch {
    state.admin.error = 'Couldn’t load admin data. Retrying…'
  } finally {
    state.admin.loading = false
  }
}

// Live refresh while the admin view is on screen.
let adminTimer: ReturnType<typeof setInterval> | null = null
watch(
  () => state.visible && state.view === 'admin' && state.isAdmin,
  (on) => {
    if (adminTimer) clearInterval(adminTimer)
    adminTimer = null
    if (!on) return
    fetchAdmin()
    adminTimer = setInterval(() => fetchAdmin(true), 4000)
  },
  { immediate: true },
)

const where = (c: { street?: string | null; label?: string }) => c.street || c.label || 'that spot'

async function adminStop(b: AdminBroadcast) {
  if (await fetchNui('adminStop', { id: b.id })) toast(`Stopped “${b.song.title}” on ${b.label}`, 'stop')
  fetchAdmin(true)
}

function adminStopNear() {
  const radius = state.admin.data?.nearbyRadius ?? 50
  askConfirm({
    title: 'Stop music near you?',
    message: `Every radio and DJ booth within ${radius} m of you will stop playing. Their owners get a notification.`,
    confirmLabel: 'Stop nearby music',
    tone: 'danger',
    icon: 'stop',
    onConfirm: async () => {
      const n = await fetchNui<number>('adminStopNear', { radius })
      toast(n ? `Stopped ${n} radio${n === 1 ? '' : 's'} near you` : 'Nothing was playing near you', 'stop')
      fetchAdmin(true)
    },
  })
}

function adminStopAll() {
  const n = state.admin.data?.broadcasts.length ?? 0
  askConfirm({
    title: 'Stop all music?',
    message: `This stops all ${n} radio${n === 1 ? '' : 's'} on the server, including every DJ booth. Use it for emergencies or server events.`,
    confirmLabel: 'Stop everything',
    tone: 'danger',
    icon: 'stop',
    onConfirm: async () => {
      const stopped = await fetchNui<number>('adminStopAll', {})
      toast(`Stopped ${stopped ?? 0} radio${stopped === 1 ? '' : 's'}`, 'stop', 'danger')
      fetchAdmin(true)
    },
  })
}

async function adminWaypoint(coords: Coords | null | undefined, label: string) {
  if (!coords) return
  if (await fetchNui('adminWaypoint', { coords })) toast(`Waypoint set: ${label}`, 'map-pin')
}

function adminTeleport(coords: Coords | null | undefined) {
  if (coords) fetchNui('adminTeleport', { coords })
}

async function adminRenameStation(s: AdminStation, label: string) {
  const clean = label.trim().slice(0, 64)
  if (!clean || clean === s.label) return
  if (await fetchNui('adminRenameStation', { id: s.id, label: clean })) {
    s.label = clean
    toast(`Renamed booth to “${clean}”`, 'edit-2')
  }
  fetchAdmin(true)
}

function adminRemoveStation(s: AdminStation) {
  askConfirm({
    title: `Remove “${s.label}”?`,
    message: `The booth at ${where(s)} disappears for everyone${s.playing ? ' and its music stops' : ''}. This can’t be undone.`,
    confirmLabel: 'Remove booth',
    tone: 'danger',
    icon: 'trash-2',
    onConfirm: async () => {
      if (await fetchNui('adminRemoveStation', { id: s.id })) toast(`Removed “${s.label}”`, 'trash-2', 'danger')
      fetchAdmin(true)
    },
  })
}

function adminEditStation(s: AdminStation) {
  fetchNui('adminEditStation', { id: s.id })
}

function adminPlaceStation() {
  fetchNui('adminPlaceStation', {})
}

async function adminBan(payload: {
  targetId?: number
  identifier?: string
  name?: string
  scope: 'dj' | 'all'
  minutes: number | null
  reason: string
  stopNow: boolean
}): Promise<string | null> {
  const res = await fetchNui<{ ok: boolean; err?: string; stopped?: number }>('adminBan', payload)
  if (!res?.ok) {
    const reasons: Record<string, string> = {
      self: 'You can’t ban yourself.',
      no_player: 'That player couldn’t be found.',
      no_permission: 'You don’t have permission to ban.',
    }
    return reasons[res?.err ?? ''] ?? 'The ban didn’t go through. Try again.'
  }
  toast(
    `${payload.name ?? 'Player'} banned from ${payload.scope === 'all' ? 'all radios' : 'DJ booths'}` +
      (res.stopped ? ` · stopped ${res.stopped} radio${res.stopped === 1 ? '' : 's'}` : ''),
    'ban',
    'danger',
  )
  state.banDraft = null
  fetchAdmin(true)
  return null
}

async function adminUnban(ban: AdminBan) {
  if (await fetchNui('adminUnban', { identifier: ban.identifier })) toast(`Unbanned ${ban.name || ban.identifier}`, 'unlock')
  fetchAdmin(true)
}

// Escape peels off the topmost layer first; only with nothing left open does it close the radio.
function dismissTopLayer(): boolean {
  if (state.widgetEditing) finishWidgetEditing()
  else if (state.menu) state.menu = null
  else if (state.popover) state.popover = null
  else if (state.confirm) state.confirm = null
  else if (state.banDraft) state.banDraft = null
  else if (state.deletePlaylistId != null) state.deletePlaylistId = null
  else if (state.editPlaylistId != null) state.editPlaylistId = null
  else if (state.inviteePlaylistId != null) state.inviteePlaylistId = null
  else if (state.createPlaylistOpen) state.createPlaylistOpen = false
  else if (state.settingsOpen) state.settingsOpen = false
  else if (state.shortcutsOpen) state.shortcutsOpen = false
  else return false
  return true
}

async function copyLink(song: Song) {
  if (!song.videoId) return
  const url = `https://www.youtube.com/watch?v=${song.videoId}`
  try {
    await navigator.clipboard.writeText(url)
  } catch {
    // CEF often refuses the async clipboard API - fall back to the legacy copy command.
    const el = document.createElement('textarea')
    el.value = url
    el.style.cssText = 'position:fixed;opacity:0;'
    document.body.appendChild(el)
    el.select()
    document.execCommand('copy')
    el.remove()
  }
  toast('Link copied to clipboard', 'link')
}

// ─── Search ────────────────────────────────────────────────────────────────

let searchTimer: ReturnType<typeof setTimeout> | null = null
let searchSeq = 0

function rememberSearch(query: string) {
  const q = query.trim()
  state.recentSearches = [q, ...state.recentSearches.filter((x) => x.toLowerCase() !== q.toLowerCase())].slice(0, 8)
  saveJson('recentSearches', state.recentSearches)
}

function forgetSearch(query?: string) {
  state.recentSearches = query ? state.recentSearches.filter((x) => x !== query) : []
  saveJson('recentSearches', state.recentSearches)
}

function retrySearch() {
  const q = state.searchQuery.trim()
  if (q.length >= 2) runSearch(q)
}

async function runSearch(query: string) {
  const seq = ++searchSeq
  state.searching = true
  state.searchError = null
  try {
    const linkId = parseYouTubeId(query)
    const results = linkId ? await fetchVideoById(linkId) : await searchYouTube(query)
    if (seq !== searchSeq) return // a newer search already replaced this one
    for (const song of results) upsertSong(song)
    state.searchResultIds = results.map((s) => s.id)
    if (results.length && !linkId) rememberSearch(query)
  } catch {
    if (seq !== searchSeq) return
    state.searchResultIds = []
    state.searchError = 'Search failed. Check your connection and try again.'
  } finally {
    if (seq === searchSeq) state.searching = false
  }
}

watch(
  () => state.searchQuery,
  (q) => {
    if (searchTimer) clearTimeout(searchTimer)
    const trimmed = q.trim()
    if (!trimmed || trimmed.length < 2 || !youtubeConfigured) {
      searchSeq++
      state.searchResultIds = []
      state.searchError = null
      state.searching = false
      return
    }
    state.searching = true
    searchTimer = setTimeout(() => runSearch(trimmed), 450)
  },
)

// ─── NUI hydration + live broadcast sync ───────────────────────────────────

async function hydrate() {
  if (!isNuiEnv) return
  const data = await fetchNui<any>('getState', {})
  if (!data) return

  state.identifier = data.identifier
  state.myName = data.name

  for (const pl of asArray<any>(data.playlists)) {
    for (const t of asArray<any>(pl.tracks)) upsertSong(toClientSong(t))
  }
  for (const row of asArray<any>(data.favorites)) upsertSong(toClientSong(row))
  for (const row of asArray<any>(data.recent)) upsertSong(toClientSong(row))

  const favPlaylist: Playlist = {
    id: 'favorites',
    name: 'Liked Songs',
    cover: null,
    hue: 335,
    songIds: asArray<any>(data.favorites).map((r: any) => r.song_id),
    ownerIdentifier: state.identifier,
    ownerName: state.myName,
    collaborators: [],
    isDefault: true,
  }
  state.playlists = [favPlaylist, ...asArray<any>(data.playlists).map(toClientPlaylist)]
  state.recentlyPlayedIds = asArray<any>(data.recent).map((r: any) => r.song_id)
  state.invites = asArray<any>(data.invites).map((row: any) => ({
    playlistId: row.playlist_id,
    name: row.name,
    hue: row.hue,
    invitedBy: row.invited_by,
    invitedByName: row.invited_by_name,
  }))
  state.isAdmin = !!data.isAdmin
  state.ban = data.ban ?? null

  // Opened with no radio bound (admin panel only): leave whatever is playing untouched.
  if (state.contextKind == null) return

  if (data.broadcast) {
    const song = songFromBroadcast(data.broadcast.song)
    upsertSong(song)
    if (isShared()) {
      const queueSongs = asArray<any>(data.broadcast.queue).map(songFromBroadcast)
      for (const s of queueSongs) upsertSong(s)
      state.queue = [
        { qid: 'current', songId: song.id, order: 0 },
        ...queueSongs.map((s: Song, i: number) => ({ qid: `q${i}`, songId: s.id, order: i + 1 })),
      ]
    } else if (currentSong.value?.id !== song.id) {
      // Reopening the personal radio keeps the local queue if it still matches what's playing.
      state.queue = [{ qid: nextQid(), songId: song.id, order: 0 }]
    }
    if (!state.queue.length || currentSong.value?.id !== song.id) state.queueCursor = 0
    state.progress = data.broadcast.progress || 0
    state.isPlaying = !!data.broadcast.playing
    state.volume = data.broadcast.volume ?? state.volume
  } else {
    state.queue = []
    state.queueCursor = 0
    state.progress = 0
    state.isPlaying = false
  }
}

const knownVideo: Record<string, string> = {}
const knownPlaying: Record<string, boolean> = {}

function handleBroadcastSync(data: { broadcasts?: Record<string, any> }) {
  const incoming = data.broadcasts || {}
  const incomingIds = new Set(Object.keys(incoming))

  // Everything on the server, for the nearby widget (which radio you're in range of comes
  // separately, via the `volume` messages).
  const live: Record<string, LiveBroadcast> = {}
  for (const [id, b] of Object.entries(incoming)) {
    if (!b.song?.videoId) continue
    live[id] = {
      id,
      kind: b.kind,
      label: b.label ?? (b.kind === 'dj' ? 'DJ booth' : b.kind === 'radiocar' ? 'Car radio' : 'Personal radio'),
      owner: b.owner,
      song: songFromBroadcast(b.song),
      playing: !!b.playing,
      progress: b.progress || 0,
      syncedAt: Date.now(),
    }
  }
  state.live = live
  for (const id of Object.keys(state.proximity)) if (!incomingIds.has(id)) delete state.proximity[id]

  for (const id of Object.keys(knownVideo)) {
    if (!incomingIds.has(id)) {
      audioEngine.destroy(id)
      delete knownVideo[id]
      delete knownPlaying[id]
      if (id === myBroadcastId) state.isPlaying = false
    }
  }

  for (const [id, b] of Object.entries(incoming)) {
    const videoId = b.song?.videoId
    if (!videoId) continue

    if (knownVideo[id] !== videoId) {
      audioEngine.play(id, videoId, b.progress || 0)
      knownVideo[id] = videoId
    } else if (knownPlaying[id] !== b.playing) {
      if (b.playing) audioEngine.resume(id)
      else audioEngine.pause(id)
    }
    knownPlaying[id] = b.playing

    if (id === myBroadcastId) {
      state.isPlaying = b.playing
      state.progress = b.progress || 0

      if (isShared()) {
        const current = songFromBroadcast(b.song)
        upsertSong(current)
        const queueSongs = asArray<any>(b.queue).map(songFromBroadcast)
        for (const s of queueSongs) upsertSong(s)
        state.queue = [
          { qid: 'current', songId: current.id, order: 0 },
          ...queueSongs.map((s: Song, i: number) => ({ qid: `q${i}`, songId: s.id, order: i + 1 })),
        ]
        state.queueCursor = 0
      }
    }
  }
}

function bindNui() {
  if (!isNuiEnv) return

  // The widget lives outside the panel, so it needs these before the radio is ever opened.
  fetchNui<any>('getConfig', {})
    .then((c) => {
      if (!c) return
      state.widgetServerEnabled = c.widget !== false
      if (c.widgetCommand) state.widgetCommand = c.widgetCommand
      if (c.serverId != null) state.serverId = c.serverId
    })
    .catch(() => {})

  onNuiMessage('open', (data) => {
    state.visible = true
    // No context = admin panel opened somewhere the radio isn't allowed; keep the old binding so
    // a personal radio that's still playing stays in sync.
    if (data.context) myBroadcastId = data.context.id
    state.contextKind = data.context?.kind ?? null
    // Shared broadcasts (dj/radiocar) advance server-side only - every viewer's own "song ended"
    // firing a local advance would race and skip multiple tracks at once.
    if (myBroadcastId) {
      audioEngine.onEnded(myBroadcastId, () => {
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
    const d = data.data
    state.creator = d
      ? { ...d, steps: asArray<string>(d.steps), options: asArray(d.options), info: asArray(d.info), keys: asArray<any>(d.keys).map((k) => ({ ...k, keys: asArray<string>(k.keys) })) }
      : null
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

export const store = {
  state,
  currentSong,
  currentEntry,
  upNext,
  activePlaylist,
  activePlaylistSongs,
  recentlyPlayed,
  searchResults,
  shared,
  anyModalOpen,
  sleepRemaining,
  youtubeConfigured,
  isNuiEnv,
  formatTime,
  formatLength,
  playSong,
  playList,
  togglePlay,
  next,
  prev,
  seek,
  seekBy,
  setVolume,
  toggleMute,
  toggleShuffle,
  cycleRepeat,
  addToQueue,
  addAllToQueue,
  playNext,
  removeFromQueue,
  reorderUpNext,
  shuffleUpNext,
  clearUpNext,
  jumpTo,
  setSleepTimer,
  setView,
  goBack,
  goForward,
  openSearch,
  playlistById,
  playlistSongs,
  createPlaylist,
  deletePlaylist,
  leavePlaylist,
  isOwnerOf,
  requestDeletePlaylist,
  cancelDeletePlaylist,
  confirmDeletePlaylist,
  renamePlaylist,
  setPlaylistCover,
  isInPlaylist,
  toggleSongInPlaylist,
  removeSongFromPlaylist,
  isFavorite,
  toggleFavorite,
  isShareable,
  inviteUser,
  removeCollaborator,
  acceptInvite,
  declineInvite,
  searchCandidates,
  openTrackMenu,
  openPlaylistMenu,
  closeMenu,
  dismissTopLayer,
  copyLink,
  rememberSearch,
  forgetSearch,
  retrySearch,
  toast,
  dismissToast,
  songById,
  bindNui,
  // nearby widget / bans
  activeBan,
  widgetBroadcast,
  liveProgress,
  startWidgetEditing,
  finishWidgetEditing,
  askConfirm,
  // admin
  fetchAdmin,
  adminStop,
  adminStopNear,
  adminStopAll,
  adminWaypoint,
  adminTeleport,
  adminRenameStation,
  adminRemoveStation,
  adminPlaceStation,
  adminEditStation,
  adminBan,
  adminUnban,
  close: () => fetchNui('close', {}),
}
