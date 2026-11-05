import { reactive, watch } from 'vue'
import type {
  AdminData,
  AdminTab,
  BanDraft,
  BroadcastKind,
  ConfirmState,
  CreatorAccess,
  CreatorHud,
  Invite,
  LiveBroadcast,
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
  Tempo,
  Toast,
  ViewKind,
} from '../types'
import {
  currentUser,
  devLiveBroadcast,
  invites as devInvites,
  playlists as devPlaylists,
  recentlyPlayedIds as devRecent,
  songs as devSongs,
} from '../data/mock'
import { isNuiEnv } from '../services/nui'
import { loadJson, loadList, saveJson } from '../utils/persist'

export type PlaylistId = string | number
export type Popover = 'sleep' | 'lights' | null

export interface State {
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
  contextBlocked: string | null
  sleepEndsAt: number | null
  sleepEndOfTrack: boolean
  now: number
  toasts: Toast[]
  focusSearchSignal: number
  visible: boolean
  serverId: number | null
  isAdmin: boolean
  ban: RadioBan | null
  djLocked: boolean
  live: Record<string, LiveBroadcast>
  proximity: Record<string, Proximity>
  widgetServerEnabled: boolean
  widgetCommand: string
  widgetEditing: boolean
  lightsEnabled: boolean
  tempo: Tempo | null
  tapCount: number
  admin: {
    data: AdminData | null
    loading: boolean
    error: string | null
    tab: AdminTab
    fetchedAt: number
  }
  confirm: ConfirmState | null
  banDraft: BanDraft | null
  creator: CreatorHud | null
  creatorAccess: CreatorAccess | null
}

export interface PendingSeek {
  to: number
  at: number
  videoId?: string
}

const dev = <T>(devValue: T, liveValue: T): T => (isNuiEnv ? liveValue : devValue)

const playerPrefs = loadJson('player', { shuffle: false, repeat: 'off' as RepeatMode })

export const state = reactive<State>({
  songs: dev([...devSongs], []),
  playlists: dev([...devPlaylists], []),
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
  recentlyPlayedIds: dev([...devRecent], []),
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
  invites: dev([...devInvites], []),
  candidates: [],
  candidateSearching: false,
  identifier: currentUser.identifier,
  myName: currentUser.name,
  contextKind: dev<BroadcastKind | null>('radio', null),
  contextBlocked: null,
  sleepEndsAt: null,
  sleepEndOfTrack: false,
  now: Date.now(),
  toasts: [],
  focusSearchSignal: 0,
  visible: !isNuiEnv,
  serverId: dev<number | null>(7, null),
  isAdmin: !isNuiEnv,
  ban: null,
  djLocked: false,
  live: dev({ [devLiveBroadcast.id]: { ...devLiveBroadcast, syncedAt: Date.now() } }, {}),
  proximity: dev({ [devLiveBroadcast.id]: { near: true, volume: 0.8 } }, {}),
  widgetServerEnabled: true,
  widgetCommand: 'radiohud',
  widgetEditing: false,
  lightsEnabled: !isNuiEnv,
  tempo: null,
  tapCount: 0,
  admin: { data: null, loading: false, error: null, tab: 'live', fetchedAt: 0 },
  confirm: null,
  banDraft: null,
  creator: null,
  creatorAccess: null,
})

export const session = {
  broadcastId: dev<string | null>('radio:dev', null),
  pendingSeek: null as PendingSeek | null,
}

watch(
  () => [state.shuffle, state.repeat],
  () => saveJson('player', { shuffle: state.shuffle, repeat: state.repeat }),
)
