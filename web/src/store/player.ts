import { computed, watch } from 'vue'
import type { BroadcastKind, PlayingFrom, QueueEntry, RadioBan, RepeatMode, Song } from '../types'
import * as audioEngine from '../services/audioEngine'
import { fetchNui, isNuiEnv } from '../services/nui'
import { shuffled } from '../utils/format'
import { session, state } from './state'
import { songById, songsByIds, upsertSong } from './songs'
import { toast } from './ui'

const RESTART_AFTER = 4
const RECENT_LIMIT = 30
const UNORDERED = 1e6

const NEXT_REPEAT: Record<RepeatMode, RepeatMode> = { off: 'all', all: 'one', one: 'off' }
const REPEAT_LABEL: Record<RepeatMode, string> = { off: 'Repeat off', all: 'Repeating queue', one: 'Repeating this song' }

let qidSeq = 1000
let lockedToastAt = 0
let parkedRadio: { queue: QueueEntry[]; cursor: number; from: PlayingFrom | null } | null = null

export const queueEntry = (songId: string, order: number): QueueEntry => ({ qid: `q${qidSeq++}`, songId, order })
const effectiveVolume = () => (state.muted ? 0 : state.volume)

export const currentEntry = computed(() => state.queue[state.queueCursor])
export const currentSong = computed(() => songById(currentEntry.value?.songId))
export const upNext = computed(() => state.queue.slice(state.queueCursor + 1))
export const recentlyPlayed = computed(() => songsByIds(state.recentlyPlayedIds))
export const shared = computed(() => state.contextKind === 'dj' || state.contextKind === 'radiocar')

export const sleepRemaining = computed(() =>
  state.sleepEndsAt ? Math.max(0, Math.round((state.sleepEndsAt - state.now) / 1000)) : null,
)

export const activeBan = computed<RadioBan | null>(() => {
  const ban = state.ban
  if (!ban) return null
  if (ban.expires_at && ban.expires_at * 1000 <= state.now) return null
  return ban.scope === 'all' || state.contextKind === 'dj' ? ban : null
})

export function bindBroadcast(id: string | null, kind: BroadcastKind | null) {
  if (id === session.broadcastId) return
  if (state.contextKind === 'radio') parkedRadio = { queue: state.queue, cursor: state.queueCursor, from: state.playingFrom }

  session.broadcastId = id
  session.pendingSeek = null
  const parked = kind === 'radio' ? parkedRadio : null
  state.queue = parked?.queue ?? []
  state.queueCursor = parked?.cursor ?? 0
  state.playingFrom = parked?.from ?? null
  state.isPlaying = false
  state.progress = 0
  state.tempo = null
}

export function setSharedQueue(current: Song, upcoming: Song[]) {
  upsertSong(current)
  upcoming.forEach(upsertSong)
  state.queue = [
    { qid: 'current', songId: current.id, order: 0 },
    ...upcoming.map((song, i) => ({ qid: `q${i}`, songId: song.id, order: i + 1 })),
  ]
  state.queueCursor = 0
}

export function controlLocked(): boolean {
  if (!state.djLocked || state.contextKind !== 'dj') return false
  if (Date.now() - lockedToastAt > 1500) {
    lockedToastAt = Date.now()
    toast('Only certain jobs can play music at this booth', 'lock', 'danger')
  }
  return true
}

function playBlocked(): boolean {
  if (isNuiEnv && state.contextKind == null) {
    toast(state.contextBlocked ?? 'Open your radio (or a DJ booth) to play music', 'radio', state.contextBlocked ? 'danger' : 'default')
    return true
  }
  if (activeBan.value) {
    toast(activeBan.value.scope === 'all' ? 'You’re banned from using the radio' : 'You’re banned from DJ booths', 'ban', 'danger')
    return true
  }
  return controlLocked()
}

function recordRecentlyPlayed(id: string) {
  state.recentlyPlayedIds = [id, ...state.recentlyPlayedIds.filter((x) => x !== id)].slice(0, RECENT_LIMIT)
}

function playShared(song: Song, upcoming: Song[]) {
  recordRecentlyPlayed(song.id)
  fetchNui('play', { song, volume: effectiveVolume(), queue: upcoming })
}

function startCurrent() {
  state.progress = 0
  const song = currentSong.value
  state.isPlaying = !!song
  if (!song) return
  recordRecentlyPlayed(song.id)
  fetchNui('play', { song, volume: effectiveVolume() })
}

function stopPlayback() {
  state.isPlaying = false
  state.progress = 0
  fetchNui('stop')
}

export function playSong(song: Song, context?: Song[], from: PlayingFrom | null = null) {
  if (playBlocked()) return
  state.playingFrom = from
  const list = context?.length ? context : [song]
  const index = Math.max(0, list.findIndex((s) => s.id === song.id))

  if (shared.value) {
    const rest = state.shuffle ? shuffled(list.filter((_, i) => i !== index)) : list.slice(index + 1)
    return playShared(song, rest)
  }

  if (state.shuffle) {
    const others = shuffled(list.map((s, order) => ({ s, order })).filter(({ order }) => order !== index))
    state.queue = [queueEntry(song.id, index), ...others.map(({ s, order }) => queueEntry(s.id, order))]
    state.queueCursor = 0
  } else {
    state.queue = list.map((s, order) => queueEntry(s.id, order))
    state.queueCursor = index
  }
  startCurrent()
}

export function playList(list: Song[], from: PlayingFrom | null, opts: { shuffle?: boolean } = {}) {
  if (!list.length) return
  if (opts.shuffle !== undefined) state.shuffle = opts.shuffle
  const start = state.shuffle ? list[Math.floor(Math.random() * list.length)] : list[0]
  playSong(start, list, from)
}

export function togglePlay() {
  if (!currentSong.value || playBlocked()) return
  state.isPlaying = !state.isPlaying
  fetchNui('togglePlay')
}

export function advance(auto = false) {
  if (auto && state.sleepEndOfTrack) {
    state.sleepEndOfTrack = false
    stopPlayback()
    toast('Sleep timer ended. Playback stopped.', 'moon')
  } else if (auto && state.repeat === 'one') {
    startCurrent()
  } else if (state.queueCursor < state.queue.length - 1) {
    state.queueCursor += 1
    startCurrent()
  } else if (state.repeat === 'all' && state.queue.length) {
    state.queueCursor = 0
    startCurrent()
  } else {
    stopPlayback()
  }
}

export function next() {
  if (controlLocked()) return
  if (shared.value) fetchNui('next')
  else advance()
}

export function prev() {
  if (controlLocked()) return
  if (state.progress <= RESTART_AFTER && !shared.value && state.queueCursor > 0) {
    state.queueCursor -= 1
    startCurrent()
  } else {
    seek(0)
  }
}

export function seek(seconds: number) {
  const song = currentSong.value
  if (!song || controlLocked()) return
  const clamped = Math.min(Math.max(0, seconds), song.duration || seconds)
  state.progress = clamped
  session.pendingSeek = { to: clamped, at: Date.now(), videoId: song.videoId }
  if (session.broadcastId) audioEngine.seek(session.broadcastId, clamped)
  fetchNui('seek', { seconds: clamped })
}

export function seekBy(delta: number) {
  seek(state.progress + delta)
}

export function setVolume(volume: number) {
  if (controlLocked()) return
  state.volume = Math.round(Math.min(100, Math.max(0, volume)))
  if (state.volume > 0) state.muted = false
  fetchNui('setVolume', { volume: effectiveVolume() })
}

export function toggleMute() {
  if (controlLocked()) return
  state.muted = !state.muted
  fetchNui('setVolume', { volume: effectiveVolume() })
}

export function toggleShuffle(announce = false) {
  state.shuffle = !state.shuffle
  if (!shared.value) {
    const head = state.queue.slice(0, state.queueCursor + 1)
    const upcoming = state.queue.slice(state.queueCursor + 1)
    state.queue = [...head, ...(state.shuffle ? shuffled(upcoming) : [...upcoming].sort((a, b) => a.order - b.order))]
  }
  if (announce) toast(state.shuffle ? 'Shuffle on' : 'Shuffle off', 'shuffle')
}

export function cycleRepeat(announce = false) {
  if (shared.value) return
  state.repeat = NEXT_REPEAT[state.repeat]
  if (announce) toast(REPEAT_LABEL[state.repeat], state.repeat === 'one' ? 'repeat-1' : 'repeat')
}

function enqueue(songs: Song[]) {
  if (shared.value) songs.forEach((song) => fetchNui('enqueue', { song }))
  else songs.forEach((song) => state.queue.push(queueEntry(song.id, UNORDERED + qidSeq)))
}

export function addToQueue(song: Song) {
  if (playBlocked()) return
  enqueue([song])
  toast(`Added “${song.title}” to queue`, 'list-plus')
}

export function addAllToQueue(list: Song[], label: string) {
  if (!list.length || playBlocked()) return
  enqueue(list)
  toast(`Added ${list.length} songs from ${label} to queue`, 'list-plus')
}

export function playNext(song: Song) {
  if (playBlocked()) return
  if (shared.value) fetchNui('enqueueNext', { song })
  else state.queue.splice(state.queueCursor + 1, 0, queueEntry(song.id, (currentEntry.value?.order ?? 0) + 0.5))
  toast(`“${song.title}” will play next`, 'skip-forward')
}

export function removeFromQueue(qid: string) {
  const index = state.queue.findIndex((entry) => entry.qid === qid)
  if (index === -1 || controlLocked()) return

  if (shared.value) {
    if (index > 0) fetchNui('removeFromQueue', { index: index - 1 })
    return
  }

  if (index < state.queueCursor) state.queueCursor -= 1
  state.queue.splice(index, 1)
}

function setUpNext(entries: QueueEntry[]) {
  if (controlLocked()) return
  if (shared.value) {
    state.queue = [...state.queue.slice(0, 1), ...entries]
    fetchNui('setQueue', { queue: songsByIds(entries.map((entry) => entry.songId)) })
    return
  }
  state.queue = [...state.queue.slice(0, state.queueCursor + 1), ...entries]
}

export function reorderUpNext(from: number, to: number) {
  const list = [...upNext.value]
  if (from === to || from < 0 || to < 0 || from >= list.length || to >= list.length) return
  const [entry] = list.splice(from, 1)
  list.splice(to, 0, entry)
  setUpNext(list)
}

export function shuffleUpNext() {
  if (upNext.value.length < 2 || controlLocked()) return
  setUpNext(shuffled(upNext.value))
  toast('Shuffled up next', 'shuffle')
}

export function clearUpNext() {
  if (!upNext.value.length || controlLocked()) return
  setUpNext([])
  toast('Cleared up next', 'trash-2')
}

export function jumpTo(qid: string) {
  const index = state.queue.findIndex((entry) => entry.qid === qid)
  const song = songById(state.queue[index]?.songId)
  if (index === -1 || !song || playBlocked()) return

  if (shared.value) {
    return playShared(song, songsByIds(state.queue.slice(index + 1).map((entry) => entry.songId)))
  }
  state.queueCursor = index
  startCurrent()
}

function pauseForSleep() {
  if (state.isPlaying) togglePlay()
  toast('Sleep timer ended. Playback paused.', 'moon')
}

export function setSleepTimer(option: number | 'end' | null) {
  state.popover = null
  state.sleepEndsAt = typeof option === 'number' ? Date.now() + option * 60_000 : null
  state.sleepEndOfTrack = option === 'end'
  if (option === null) toast('Sleep timer off', 'moon')
  else if (option === 'end') toast('Playback will stop after this song', 'moon')
  else toast(`Sleep timer set for ${option < 60 ? `${option} min` : `${option / 60} hr`}`, 'moon')
}

watch(
  () => currentSong.value?.id,
  (id, previousId) => {
    if (!state.sleepEndOfTrack || !shared.value || !previousId || id === previousId) return
    state.sleepEndOfTrack = false
    pauseForSleep()
  },
)

setInterval(() => {
  state.now = Date.now()
  if (state.sleepEndsAt && state.now >= state.sleepEndsAt) {
    state.sleepEndsAt = null
    pauseForSleep()
  }

  const song = currentSong.value
  if (!state.isPlaying || !song) return
  if (state.progress < song.duration) state.progress += 1
  else if (!isNuiEnv) advance(true)
}, 1000)
