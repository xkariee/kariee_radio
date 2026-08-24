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

export type ViewKind = 'recent' | 'queue' | 'playlist'

export interface MenuState {
  kind: 'track' | 'playlist'
  trackId?: string
  playlistId?: number | string
  contextPlaylistId?: number | string
  x: number
  y: number
}

export type BroadcastContext =
  | { kind: 'radio'; id: string }
  | { kind: 'dj'; id: string; stationId: number }
  | { kind: 'radiocar'; id: string; vehicleNetId: number }
