import { computed, reactive, watch } from 'vue'
import type { MenuState, Playlist, Song, User, ViewKind } from './types'
import { currentUser, mockUsers, playlists as initialPlaylists, songs as initialSongs } from './data/mock'
import { searchYouTube, youtubeConfigured } from './services/youtube'
import * as ytPlayer from './services/ytPlayer'

interface QueueEntry {
  qid: string
  songId: string
}

interface State {
  songs: Song[]
  playlists: Playlist[]
  users: User[]
  queue: QueueEntry[]
  queueCursor: number
  isPlaying: boolean
  progress: number
  volume: number
  muted: boolean
  view: ViewKind
  activePlaylistId: string | null
  recentlyPlayedIds: string[]
  searchQuery: string
  searching: boolean
  searchError: string | null
  searchResultIds: string[]
  menu: MenuState | null
  createPlaylistOpen: boolean
  editPlaylistId: string | null
  inviteePlaylistId: string | null
  deletePlaylistId: string | null
}

const state = reactive<State>({
  songs: initialSongs,
  playlists: initialPlaylists,
  users: mockUsers,
  queue: [],
  queueCursor: 0,
  isPlaying: false,
  progress: 0,
  volume: 68,
  muted: false,
  view: 'recent',
  activePlaylistId: null,
  recentlyPlayedIds: ['s1', 's3'],
  searchQuery: '',
  searching: false,
  searchError: null,
  searchResultIds: [],
  menu: null,
  createPlaylistOpen: false,
  editPlaylistId: null,
  inviteePlaylistId: null,
  deletePlaylistId: null,
})

let qidSeq = 1000
const nextQid = () => `q${qidSeq++}`
let pidSeq = 100
const nextPid = () => `p${pidSeq++}`

function songById(id: string | undefined) {
  return id ? state.songs.find((s) => s.id === id) : undefined
}

const currentEntry = computed(() => state.queue[state.queueCursor])
const currentSong = computed(() => songById(currentEntry.value?.songId))

const upNext = computed(() => state.queue.slice(state.queueCursor + 1))

const activePlaylist = computed(() =>
  state.activePlaylistId ? state.playlists.find((p) => p.id === state.activePlaylistId) ?? null : null,
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

// local (mock) tracks are simulated with a progress timer; youtube tracks report
// real progress via the hidden IFrame player's polling instead.
let tickHandle: ReturnType<typeof setInterval> | null = null
function ensureTicking() {
  if (tickHandle) return
  tickHandle = setInterval(() => {
    if (!state.isPlaying) return
    const song = currentSong.value
    if (!song || song.source === 'youtube') return
    if (state.progress >= song.duration) {
      advance()
      return
    }
    state.progress += 1
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
    ytPlayer.pause()
    return
  }
  recordRecentlyPlayed(song.id)
  state.isPlaying = true
  if (song.source === 'youtube' && song.videoId) {
    ytPlayer.playVideo(song.videoId)
  } else {
    ytPlayer.pause()
  }
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
  if (song.source === 'youtube') {
    if (state.isPlaying) ytPlayer.play()
    else ytPlayer.pause()
  }
}

function advance() {
  if (state.queueCursor < state.queue.length - 1) {
    state.queueCursor += 1
    syncCurrentPlayback()
  } else {
    state.isPlaying = false
    state.progress = 0
    ytPlayer.pause()
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
  if (song.source === 'youtube') ytPlayer.seekTo(clamped)
}

function setVolume(v: number) {
  state.volume = Math.min(100, Math.max(0, v))
  if (state.volume > 0) state.muted = false
  ytPlayer.setVolume(state.muted ? 0 : state.volume)
}

function toggleMute() {
  state.muted = !state.muted
  if (state.muted) ytPlayer.mute()
  else ytPlayer.unmute()
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

function setView(view: ViewKind, playlistId: string | null = null) {
  state.view = view
  state.activePlaylistId = playlistId
  state.searchQuery = ''
}

function playlistById(id: string) {
  return state.playlists.find((p) => p.id === id)
}

function createPlaylist(name: string, cover: string | null) {
  const pl: Playlist = {
    id: nextPid(),
    name: name.trim() || 'Untitled Playlist',
    cover,
    hue: Math.floor(Math.random() * 360),
    songIds: [],
    ownerId: currentUser.id,
    collaboratorIds: [],
  }
  state.playlists.push(pl)
  state.createPlaylistOpen = false
  setView('playlist', pl.id)
  return pl
}

function deletePlaylist(id: string) {
  const pl = playlistById(id)
  if (!pl || pl.isDefault) return
  state.playlists = state.playlists.filter((p) => p.id !== id)
  if (state.activePlaylistId === id) setView('recent')
  if (state.editPlaylistId === id) state.editPlaylistId = null
}

function requestDeletePlaylist(id: string) {
  const pl = playlistById(id)
  if (!pl || pl.isDefault) return
  state.editPlaylistId = null
  state.deletePlaylistId = id
}

function cancelDeletePlaylist() {
  state.deletePlaylistId = null
}

function confirmDeletePlaylist() {
  if (state.deletePlaylistId) deletePlaylist(state.deletePlaylistId)
  state.deletePlaylistId = null
}

function renamePlaylist(id: string, name: string) {
  const pl = playlistById(id)
  if (pl && !pl.isDefault && name.trim()) pl.name = name.trim()
}

function setPlaylistCover(id: string, cover: string | null) {
  const pl = playlistById(id)
  if (pl && !pl.isDefault) pl.cover = cover
}

function isInPlaylist(playlistId: string, songId: string) {
  return playlistById(playlistId)?.songIds.includes(songId) ?? false
}

function toggleSongInPlaylist(playlistId: string, songId: string) {
  const pl = playlistById(playlistId)
  if (!pl) return
  const idx = pl.songIds.indexOf(songId)
  if (idx === -1) pl.songIds.push(songId)
  else pl.songIds.splice(idx, 1)
}

function removeSongFromPlaylist(playlistId: string, songId: string) {
  const pl = playlistById(playlistId)
  if (!pl) return
  pl.songIds = pl.songIds.filter((id) => id !== songId)
}

function isFavorite(songId: string) {
  return isInPlaylist('favorites', songId)
}

function toggleFavorite(songId: string) {
  toggleSongInPlaylist('favorites', songId)
}

function inviteUser(playlistId: string, userId: string) {
  const pl = playlistById(playlistId)
  if (!pl || pl.isDefault || pl.collaboratorIds.includes(userId) || pl.ownerId === userId) return
  pl.collaboratorIds.push(userId)
}

function removeCollaborator(playlistId: string, userId: string) {
  const pl = playlistById(playlistId)
  if (!pl) return
  pl.collaboratorIds = pl.collaboratorIds.filter((id) => id !== userId)
}

function openTrackMenu(trackId: string, x: number, y: number, contextPlaylistId?: string) {
  state.menu = { kind: 'track', trackId, x, y, contextPlaylistId }
}

function openPlaylistMenu(playlistId: string, x: number, y: number) {
  state.menu = { kind: 'playlist', playlistId, x, y }
}

function closeMenu() {
  state.menu = null
}

function upsertSong(song: Song) {
  const idx = state.songs.findIndex((s) => s.id === song.id)
  if (idx === -1) state.songs.push(song)
  else state.songs[idx] = song
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

function initYoutubePlayer(elementId: string) {
  ytPlayer.initPlayer(elementId, {
    onProgress: (sec) => {
      const song = currentSong.value
      if (!song || song.source !== 'youtube') return
      state.progress = sec
      if (!song.duration) {
        const d = ytPlayer.getDuration()
        if (d > 0) song.duration = Math.round(d)
      }
    },
    onEnded: () => advance(),
  })
}

export const store = {
  state,
  currentUser,
  currentSong,
  currentEntry,
  upNext,
  activePlaylist,
  activePlaylistSongs,
  recentlyPlayed,
  searchResults,
  youtubeConfigured,
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
  openTrackMenu,
  openPlaylistMenu,
  closeMenu,
  songById,
  initYoutubePlayer,
}
