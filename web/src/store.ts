import { computed, reactive, watch } from 'vue'
import type { Invite, MenuState, OnlineCandidate, Playlist, Song, ViewKind } from './types'
import { currentUser, playlists as mockPlaylists, songs as mockSongs } from './data/mock'
import { searchYouTube, youtubeConfigured } from './services/youtube'
import * as audioEngine from './services/audioEngine'
import { fetchNui, isNuiEnv, onNuiMessage } from './services/nui'

type PlaylistId = string | number

interface QueueEntry {
  qid: string
  songId: string
}

interface State {
  songs: Song[]
  playlists: Playlist[]
  queue: QueueEntry[]
  queueCursor: number
  isPlaying: boolean
  progress: number
  volume: number
  muted: boolean
  view: ViewKind
  activePlaylistId: PlaylistId | null
  recentlyPlayedIds: string[]
  searchQuery: string
  searching: boolean
  searchError: string | null
  searchResultIds: string[]
  menu: MenuState | null
  createPlaylistOpen: boolean
  editPlaylistId: PlaylistId | null
  inviteePlaylistId: PlaylistId | null
  deletePlaylistId: PlaylistId | null
  invites: Invite[]
  candidates: OnlineCandidate[]
  candidateSearching: boolean
  identifier: string
  myName: string
  visible: boolean
}

const state = reactive<State>({
  songs: isNuiEnv ? [] : [...mockSongs],
  playlists: isNuiEnv ? [] : [...mockPlaylists],
  queue: [],
  queueCursor: 0,
  isPlaying: false,
  progress: 0,
  volume: 68,
  muted: false,
  view: 'recent',
  activePlaylistId: null,
  recentlyPlayedIds: [],
  searchQuery: '',
  searching: false,
  searchError: null,
  searchResultIds: [],
  menu: null,
  createPlaylistOpen: false,
  editPlaylistId: null,
  inviteePlaylistId: null,
  deletePlaylistId: null,
  invites: [],
  candidates: [],
  candidateSearching: false,
  identifier: currentUser.identifier,
  myName: currentUser.name,
  visible: !isNuiEnv,
})

let myBroadcastId: string | null = isNuiEnv ? null : 'radio:dev'

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
    collaborators: (row.collaborators ?? []).map((c: any) => ({ identifier: c.identifier, name: c.name ?? c.identifier })),
    songIds: (row.tracks ?? []).map((t: any) => t.song_id),
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

function formatTime(sec: number): string {
  const m = Math.floor(sec / 60)
  const s = Math.floor(sec % 60)
  return `${m}:${s.toString().padStart(2, '0')}`
}

// Ticks the displayed progress bar between authoritative server syncs.
let tickHandle: ReturnType<typeof setInterval> | null = null
function ensureTicking() {
  if (tickHandle) return
  tickHandle = setInterval(() => {
    if (!state.isPlaying) return
    const song = currentSong.value
    if (!song) return
    if (state.progress < song.duration) state.progress += 1
  }, 1000)
}
ensureTicking()

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
  fetchNui('play', { song, volume: state.muted ? 0 : state.volume })
}

function playSong(song: Song, context?: Song[]) {
  const list = context && context.length ? context : [song]
  state.queue = list.map((s) => ({ qid: nextQid(), songId: s.id }))
  state.queueCursor = Math.max(
    0,
    list.findIndex((s) => s.id === song.id),
  )
  syncCurrentPlayback()
}

function togglePlay() {
  const song = currentSong.value
  if (!song) return
  state.isPlaying = !state.isPlaying
  fetchNui('togglePlay', {})
}

function advance() {
  if (state.queueCursor < state.queue.length - 1) {
    state.queueCursor += 1
    syncCurrentPlayback()
  } else {
    state.isPlaying = false
    state.progress = 0
    fetchNui('stop', {})
  }
}

function next() {
  advance()
}

function prev() {
  if (state.progress > 4 && currentSong.value) {
    seek(0)
    return
  }
  if (state.queueCursor > 0) {
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

function setVolume(v: number) {
  state.volume = Math.min(100, Math.max(0, v))
  if (state.volume > 0) state.muted = false
  fetchNui('setVolume', { volume: state.muted ? 0 : state.volume })
}

function toggleMute() {
  state.muted = !state.muted
  fetchNui('setVolume', { volume: state.muted ? 0 : state.volume })
}

function addToQueue(song: Song) {
  state.queue.push({ qid: nextQid(), songId: song.id })
}

function playNext(song: Song) {
  state.queue.splice(state.queueCursor + 1, 0, { qid: nextQid(), songId: song.id })
}

function removeFromQueue(qid: string) {
  const idx = state.queue.findIndex((e) => e.qid === qid)
  if (idx === -1) return
  if (idx < state.queueCursor) state.queueCursor -= 1
  state.queue.splice(idx, 1)
}

function setView(view: ViewKind, playlistId: PlaylistId | null = null) {
  state.view = view
  state.activePlaylistId = playlistId
  state.searchQuery = ''
}

function playlistById(id: PlaylistId) {
  return state.playlists.find((p) => p.id === id)
}

async function createPlaylist(name: string, cover: string | null) {
  const row = await fetchNui<any>('createPlaylist', { name, cover })
  if (!row) return null
  const pl = toClientPlaylist(row)
  state.playlists.push(pl)
  state.createPlaylistOpen = false
  setView('playlist', pl.id)
  return pl
}

function deletePlaylist(id: PlaylistId) {
  const pl = playlistById(id)
  if (!pl || pl.isDefault) return
  state.playlists = state.playlists.filter((p) => p.id !== id)
  if (state.activePlaylistId === id) setView('recent')
  if (state.editPlaylistId === id) state.editPlaylistId = null
  fetchNui('deletePlaylist', { id })
}

function requestDeletePlaylist(id: PlaylistId) {
  const pl = playlistById(id)
  if (!pl || pl.isDefault) return
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
  if (pl && !pl.isDefault && name.trim()) {
    pl.name = name.trim()
    fetchNui('renamePlaylist', { id, name: pl.name })
  }
}

function setPlaylistCover(id: PlaylistId, cover: string | null) {
  const pl = playlistById(id)
  if (pl && !pl.isDefault) {
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
  if (idx === -1) {
    pl.songIds.push(songId)
    if (playlistId === 'favorites') fetchNui('toggleFavorite', { song: songById(songId) })
    else fetchNui('addTrack', { playlistId, song: songById(songId) })
  } else {
    pl.songIds.splice(idx, 1)
    if (playlistId === 'favorites') fetchNui('toggleFavorite', { song: songById(songId) })
    else fetchNui('removeTrack', { playlistId, songId })
  }
}

function removeSongFromPlaylist(playlistId: PlaylistId, songId: string) {
  const pl = playlistById(playlistId)
  if (!pl) return
  pl.songIds = pl.songIds.filter((id) => id !== songId)
  if (playlistId === 'favorites') fetchNui('toggleFavorite', { song: songById(songId) })
  else fetchNui('removeTrack', { playlistId, songId })
}

function isFavorite(songId: string) {
  return isInPlaylist('favorites', songId)
}

function toggleFavorite(songId: string) {
  toggleSongInPlaylist('favorites', songId)
}

async function inviteUser(playlistId: PlaylistId, targetId: number) {
  await fetchNui('invite', { playlistId, targetId })
}

function removeCollaborator(playlistId: PlaylistId, identifier: string) {
  const pl = playlistById(playlistId)
  if (!pl) return
  pl.collaborators = pl.collaborators.filter((c) => c.identifier !== identifier)
  fetchNui('removeCollaborator', { playlistId, identifier })
}

async function acceptInvite(playlistId: PlaylistId) {
  const row = await fetchNui<any>('acceptInvite', { playlistId })
  state.invites = state.invites.filter((i) => i.playlistId !== playlistId)
  if (row) {
    for (const t of row.tracks || []) upsertSong(toClientSong(t))
    if (!state.playlists.some((p) => p.id === row.id)) state.playlists.push(toClientPlaylist(row))
  }
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
    state.candidates = await fetchNui<OnlineCandidate[]>('searchPlayers', { query })
    state.candidateSearching = false
  }, 250)
}

function openTrackMenu(trackId: string, x: number, y: number, contextPlaylistId?: PlaylistId) {
  state.menu = { kind: 'track', trackId, x, y, contextPlaylistId }
}

function openPlaylistMenu(playlistId: PlaylistId, x: number, y: number) {
  state.menu = { kind: 'playlist', playlistId, x, y }
}

function closeMenu() {
  state.menu = null
}

let searchTimer: ReturnType<typeof setTimeout> | null = null

async function runSearch(query: string) {
  state.searching = true
  state.searchError = null
  try {
    const results = await searchYouTube(query)
    for (const song of results) upsertSong(song)
    state.searchResultIds = results.map((s) => s.id)
  } catch {
    state.searchResultIds = []
    state.searchError = 'Search failed. Please try again.'
  } finally {
    state.searching = false
  }
}

watch(
  () => state.searchQuery,
  (q) => {
    if (searchTimer) clearTimeout(searchTimer)
    const trimmed = q.trim()
    if (!trimmed || trimmed.length < 2 || !youtubeConfigured) {
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

  for (const pl of data.playlists || []) {
    for (const t of pl.tracks || []) upsertSong(toClientSong(t))
  }
  for (const row of data.favorites || []) upsertSong(toClientSong(row))
  for (const row of data.recent || []) upsertSong(toClientSong(row))

  const favPlaylist: Playlist = {
    id: 'favorites',
    name: 'My Favourites',
    cover: null,
    hue: 335,
    songIds: (data.favorites || []).map((r: any) => r.song_id),
    ownerIdentifier: state.identifier,
    ownerName: state.myName,
    collaborators: [],
    isDefault: true,
  }
  state.playlists = [favPlaylist, ...(data.playlists || []).map(toClientPlaylist)]
  state.recentlyPlayedIds = (data.recent || []).map((r: any) => r.song_id)
  state.invites = (data.invites || []).map((row: any) => ({
    playlistId: row.playlist_id,
    name: row.name,
    hue: row.hue,
    invitedBy: row.invited_by,
    invitedByName: row.invited_by_name,
  }))

  if (data.broadcast) {
    const song = songFromBroadcast(data.broadcast.song)
    upsertSong(song)
    state.queue = [{ qid: nextQid(), songId: song.id }]
    state.queueCursor = 0
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
    }
  }
}

function bindNui() {
  if (!isNuiEnv) return

  onNuiMessage('open', (data) => {
    state.visible = true
    myBroadcastId = data.context?.id ?? null
    if (myBroadcastId) audioEngine.onEnded(myBroadcastId, () => advance())
    hydrate()
  })

  onNuiMessage('close', () => {
    state.visible = false
  })

  onNuiMessage('broadcastSync', handleBroadcastSync)

  onNuiMessage('volume', (data) => {
    audioEngine.setVolume(data.id, data.volume)
  })

  onNuiMessage('inviteReceived', (data) => {
    state.invites.push(data.invite)
  })

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && state.visible) fetchNui('close', {})
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
  youtubeConfigured,
  isNuiEnv,
  formatTime,
  playSong,
  togglePlay,
  next,
  prev,
  seek,
  setVolume,
  toggleMute,
  addToQueue,
  playNext,
  removeFromQueue,
  setView,
  playlistById,
  createPlaylist,
  deletePlaylist,
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
  inviteUser,
  removeCollaborator,
  acceptInvite,
  declineInvite,
  searchCandidates,
  openTrackMenu,
  openPlaylistMenu,
  closeMenu,
  songById,
  bindNui,
  close: () => fetchNui('close', {}),
}
