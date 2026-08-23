export interface User {
  id: string
  name: string
  color: string
}

export interface Song {
  id: string
  title: string
  artist: string
  duration: number
  hue: number
  source: 'local' | 'youtube'
  videoId?: string
  thumbnail?: string | null
}

export interface Playlist {
  id: string
  name: string
  cover: string | null
  hue: number
  songIds: string[]
  ownerId: string
  collaboratorIds: string[]
  isDefault?: boolean
}

export type ViewKind = 'recent' | 'queue' | 'playlist'

export interface MenuState {
  kind: 'track' | 'playlist'
  trackId?: string
  playlistId?: string
  contextPlaylistId?: string
  x: number
  y: number
}
