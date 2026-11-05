import type { Playlist, Song } from '../types'
import { asArray } from '../utils/format'
import { state } from './state'

export function songById(id: string | undefined): Song | undefined {
  return id ? state.songs.find((song) => song.id === id) : undefined
}

export function songsByIds(ids: string[]): Song[] {
  return ids.map(songById).filter((song): song is Song => !!song)
}

export function upsertSong(song: Song) {
  const index = state.songs.findIndex((s) => s.id === song.id)
  if (index === -1) state.songs.push(song)
  else state.songs[index] = song
}

export function songFromRow(row: any): Song {
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

export function songFromPayload(payload: any): Song {
  return {
    id: payload.songId,
    title: payload.title,
    artist: payload.artist,
    duration: payload.duration,
    hue: payload.hue,
    videoId: payload.videoId,
    thumbnail: payload.thumbnail ?? null,
  }
}

export function playlistFromRow(row: any): Playlist {
  return {
    id: row.id,
    name: row.name,
    cover: row.cover ?? null,
    hue: row.hue,
    isDefault: !!row.is_default,
    ownerIdentifier: row.owner_identifier,
    ownerName: row.owner_name ?? row.owner_identifier,
    collaborators: asArray<any>(row.collaborators).map((c) => ({ identifier: c.identifier, name: c.name ?? c.identifier })),
    songIds: asArray<any>(row.tracks).map((track) => track.song_id),
  }
}
