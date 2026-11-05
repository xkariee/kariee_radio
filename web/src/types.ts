export interface Song {
  id: string
  title: string
  artist: string
  duration: number
  hue: number
  videoId: string
  thumbnail?: string | null
}

export interface Collaborator {
  identifier: string
  name: string
}

export interface Playlist {
  id: number | string
  name: string
  cover: string | null
  hue: number
  songIds: string[]
  ownerIdentifier: string
  ownerName: string
  collaborators: Collaborator[]
  isDefault?: boolean
}

export interface Invite {
  playlistId: number | string
  name: string
  hue: number
  invitedBy: string
  invitedByName: string
}

export interface OnlineCandidate {
  id: number
  name: string
}

export type ViewKind = 'home' | 'search' | 'recent' | 'queue' | 'playlist' | 'admin'

export type RepeatMode = 'off' | 'all' | 'one'

export type BroadcastKind = 'radio' | 'dj' | 'radiocar'

export interface Nav {
  view: ViewKind
  playlistId: number | string | null
}

export interface QueueEntry {
  qid: string
  songId: string
  order: number
}

export interface PlayingFrom {
  label: string
  nav: Nav | null
}

export interface Toast {
  id: number
  text: string
  icon: string
  tone: 'default' | 'like' | 'danger'
}

export interface MenuAnchor {
  x: number
  y: number
  align: 'start' | 'end'
}

export interface MenuState extends MenuAnchor {
  kind: 'track' | 'playlist'
  trackId?: string
  playlistId?: number | string
  contextPlaylistId?: number | string
}

export interface RadioBan {
  scope: 'dj' | 'all'
  reason: string
  expires_at: number | null
}

export interface Tempo {
  bpm: number
  offset: number
}

export interface LiveBroadcast {
  id: string
  kind: BroadcastKind
  label: string
  owner?: number
  song: Song
  playing: boolean
  progress: number
  syncedAt: number
}

export interface Proximity {
  near: boolean
  volume: number
}

export interface Coords {
  x: number
  y: number
  z: number
}

interface Located {
  coords?: Coords | null
  street?: string | null
  zone?: string | null
  distance?: number
  interior?: boolean
}

export interface AdminBroadcast extends Located {
  id: string
  kind: BroadcastKind
  label: string
  stationId?: number
  playing: boolean
  volume: number
  progress: number
  song: Song
  queueLength: number
  ownerId?: number
  ownerName: string
  ownerIdentifier?: string
  startedAt?: number
  nearbyPlayers: number
}

export interface AdminStation extends Located {
  id: number
  label: string
  ownerIdentifier: string
  ownerName: string
  createdAt?: number
  broadcastId: string
  playing: boolean
  song: Song | null
  setup?: {
    mode: 'prop' | 'entity' | 'zone'
    audio: 'interior' | 'radius' | 'area' | 'auto'
    range?: number
    muffled?: number
    areaPoints: number
    lights: number
    access?: string[]
  }
}

export interface CreatorHud {
  editing: boolean
  label?: string
  step: number
  steps: string[]
  title: string
  subtitle?: string
  options: { label: string; active: boolean }[]
  info: { label: string; value: string; swatch?: number[] | 'rainbow' }[]
  keys: { keys: string[]; label: string }[]
  warning?: string | null
}

export interface JobInfo {
  name: string
  label: string
  grades: { grade: number; label: string }[]
}

export interface DjAccessRule {
  job: string
  grade: number
}

export interface CreatorAccess {
  jobs: JobInfo[]
  access: DjAccessRule[]
}

export interface AdminBan {
  identifier: string
  name: string
  scope: 'dj' | 'all'
  reason: string
  bannedBy: string
  expiresAt: number | null
  createdAt: number
  online: boolean
}

export interface AdminActivity {
  t: number
  action: string
  detail: string
  actor: string
  actorId?: number
  identifier?: string
  kind?: BroadcastKind
  label?: string
  target?: string
  targetIdentifier?: string
  videoId?: string
}

export interface AdminPlayer {
  id: number
  name: string
  identifier: string
}

export interface AdminData {
  now: number
  me?: number
  nearbyRadius: number
  broadcasts: AdminBroadcast[]
  stations: AdminStation[]
  bans: AdminBan[]
  players: AdminPlayer[]
  activity: AdminActivity[]
}

export type AdminTab = 'live' | 'booths' | 'bans' | 'activity'

export interface ConfirmState {
  title: string
  message: string
  confirmLabel: string
  tone: 'danger' | 'default'
  icon: string
  onConfirm: () => void
}

export interface BanDraft {
  targetId?: number
  identifier?: string
  name?: string
}

export type BroadcastContext =
  | { kind: 'radio'; id: string }
  | { kind: 'dj'; id: string; stationId: number }
  | { kind: 'radiocar'; id: string; vehicleNetId: number }
