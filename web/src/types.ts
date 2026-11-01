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

export type ViewKind = 'home' | 'search' | 'recent' | 'queue' | 'playlist'

export type RepeatMode = 'off' | 'all' | 'one'

export type BroadcastKind = 'radio' | 'dj' | 'radiocar'

export interface Nav {
  view: ViewKind
  playlistId: number | string | null
}

export interface QueueEntry {
  qid: string
  songId: string
  // Position in the list playback started from - lets shuffle be switched off again without
  // losing the original order.
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
  // 'end' = the menu's right edge lines up with x (opened from a button on the right of a row).
  align: 'start' | 'end'
}

export interface MenuState extends MenuAnchor {
  kind: 'track' | 'playlist'
  trackId?: string
  playlistId?: number | string
  contextPlaylistId?: number | string
}

export type BroadcastContext =
  | { kind: 'radio'; id: string }
  | { kind: 'dj'; id: string; stationId: number }
  | { kind: 'radiocar'; id: string; vehicleNetId: number }
