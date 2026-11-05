import { computed } from 'vue'
import type { OnlineCandidate, Playlist } from '../types'
import { fetchNui } from '../services/nui'
import { asArray } from '../utils/format'
import { state, type PlaylistId } from './state'
import { playlistFromRow, songById, songFromRow, songsByIds, upsertSong } from './songs'
import { forgetPlaylistNav, setView } from './navigation'
import { toast } from './ui'

const FAVORITES = 'favorites'

let candidateTimer: ReturnType<typeof setTimeout> | null = null

export function playlistById(id: PlaylistId) {
  return state.playlists.find((playlist) => playlist.id === id)
}

export function playlistSongs(id: PlaylistId) {
  return songsByIds(playlistById(id)?.songIds ?? [])
}

export const activePlaylist = computed(() =>
  state.activePlaylistId != null ? (playlistById(state.activePlaylistId) ?? null) : null,
)

export const activePlaylistSongs = computed(() => songsByIds(activePlaylist.value?.songIds ?? []))

export function isOwnerOf(playlist: Playlist) {
  return !playlist.isDefault && playlist.ownerIdentifier === state.identifier
}

export function isShareable(playlist: Playlist) {
  return playlist.collaborators.length > 0 || playlist.ownerIdentifier !== state.identifier
}

export async function createPlaylist(name: string, cover: string | null) {
  const row = await fetchNui('createPlaylist', { name, cover })
  if (!row) return null
  const playlist = playlistFromRow(row)
  state.playlists.push(playlist)
  state.createPlaylistOpen = false
  setView('playlist', playlist.id)
  toast(`Created “${playlist.name}”`, 'plus')
  return playlist
}

function dropPlaylist(id: PlaylistId) {
  state.playlists = state.playlists.filter((playlist) => playlist.id !== id)
  if (state.editPlaylistId === id) state.editPlaylistId = null
  if (state.inviteePlaylistId === id) state.inviteePlaylistId = null
  forgetPlaylistNav(id)
}

export function deletePlaylist(id: PlaylistId) {
  const playlist = playlistById(id)
  if (!playlist || !isOwnerOf(playlist)) return
  dropPlaylist(id)
  fetchNui('deletePlaylist', { id })
  toast(`Deleted “${playlist.name}”`, 'trash-2', 'danger')
}

export function leavePlaylist(id: PlaylistId) {
  const playlist = playlistById(id)
  if (!playlist || playlist.isDefault || isOwnerOf(playlist)) return
  dropPlaylist(id)
  fetchNui('removeCollaborator', { playlistId: id, identifier: state.identifier })
  toast(`Left “${playlist.name}”`, 'x')
}

export function requestDeletePlaylist(id: PlaylistId) {
  const playlist = playlistById(id)
  if (!playlist || !isOwnerOf(playlist)) return
  state.editPlaylistId = null
  state.deletePlaylistId = id
}

export function cancelDeletePlaylist() {
  state.deletePlaylistId = null
}

export function confirmDeletePlaylist() {
  if (state.deletePlaylistId != null) deletePlaylist(state.deletePlaylistId)
  state.deletePlaylistId = null
}

export function renamePlaylist(id: PlaylistId, name: string) {
  const playlist = playlistById(id)
  const clean = name.trim()
  if (!playlist || playlist.isDefault || !clean || clean === playlist.name) return
  playlist.name = clean
  fetchNui('renamePlaylist', { id, name: clean })
}

export function setPlaylistCover(id: PlaylistId, cover: string | null) {
  const playlist = playlistById(id)
  if (!playlist || playlist.isDefault || cover === playlist.cover) return
  playlist.cover = cover
  fetchNui('setPlaylistCover', { id, cover })
}

export function isInPlaylist(playlistId: PlaylistId, songId: string) {
  return playlistById(playlistId)?.songIds.includes(songId) ?? false
}

export function toggleSongInPlaylist(playlistId: PlaylistId, songId: string) {
  const playlist = playlistById(playlistId)
  if (!playlist) return
  const index = playlist.songIds.indexOf(songId)
  const adding = index === -1
  if (adding) playlist.songIds.push(songId)
  else playlist.songIds.splice(index, 1)

  if (playlistId === FAVORITES) {
    fetchNui('toggleFavorite', { song: songById(songId) })
    toast(adding ? 'Added to Liked Songs' : 'Removed from Liked Songs', 'heart', 'like')
    return
  }

  if (adding) fetchNui('addTrack', { playlistId, song: songById(songId) })
  else fetchNui('removeTrack', { playlistId, songId })
  toast(adding ? `Added to ${playlist.name}` : `Removed from ${playlist.name}`, adding ? 'check' : 'x')
}

export function removeSongFromPlaylist(playlistId: PlaylistId, songId: string) {
  if (isInPlaylist(playlistId, songId)) toggleSongInPlaylist(playlistId, songId)
}

export function isFavorite(songId: string) {
  return isInPlaylist(FAVORITES, songId)
}

export function toggleFavorite(songId: string) {
  toggleSongInPlaylist(FAVORITES, songId)
}

export function favoritesPlaylist(songIds: string[]): Playlist {
  return {
    id: FAVORITES,
    name: 'Liked Songs',
    cover: null,
    hue: 335,
    songIds,
    ownerIdentifier: state.identifier,
    ownerName: state.myName,
    collaborators: [],
    isDefault: true,
  }
}

export async function inviteUser(playlistId: PlaylistId, target: OnlineCandidate) {
  await fetchNui('invite', { playlistId, targetId: target.id })
  toast(`Invite sent to ${target.name}`, 'user-plus')
}

export function removeCollaborator(playlistId: PlaylistId, identifier: string) {
  const playlist = playlistById(playlistId)
  if (!playlist) return
  playlist.collaborators = playlist.collaborators.filter((c) => c.identifier !== identifier)
  fetchNui('removeCollaborator', { playlistId, identifier })
}

function dropInvite(playlistId: PlaylistId) {
  state.invites = state.invites.filter((invite) => invite.playlistId !== playlistId)
}

export async function acceptInvite(playlistId: PlaylistId) {
  const invite = state.invites.find((i) => i.playlistId === playlistId)
  const row = await fetchNui('acceptInvite', { playlistId })
  dropInvite(playlistId)
  if (row) {
    asArray(row.tracks).forEach((track) => upsertSong(songFromRow(track)))
    if (!state.playlists.some((playlist) => playlist.id === row.id)) state.playlists.push(playlistFromRow(row))
  }
  if (invite) toast(`Joined “${invite.name}”`, 'users')
}

export function declineInvite(playlistId: PlaylistId) {
  dropInvite(playlistId)
  fetchNui('declineInvite', { playlistId })
}

export function searchCandidates(query: string) {
  if (candidateTimer) clearTimeout(candidateTimer)
  state.candidateSearching = true
  candidateTimer = setTimeout(async () => {
    state.candidates = (await fetchNui<OnlineCandidate[]>('searchPlayers', { query })) ?? []
    state.candidateSearching = false
  }, 250)
}
