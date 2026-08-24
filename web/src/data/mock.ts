import type { Song, Playlist } from '../types'

// Only used when running `npm run dev` in a plain browser (no GetParentResourceName), so the UI
// can still be iterated on standalone. None of this is real playable media or real identifiers.

export const currentUser = { identifier: 'dev:local', name: 'You' }

const otherUsers = [
  { identifier: 'dev:skyla', name: 'Skyla' },
  { identifier: 'dev:drex', name: 'Drex' },
  { identifier: 'dev:mako', name: 'Mako' },
]

export const songs: Song[] = [
  { id: 's1', title: 'Night Drive', artist: 'Vela Cruz', duration: 214, hue: 172, videoId: '' },
  { id: 's2', title: 'Static Bloom', artist: 'Halcyon Ray', duration: 189, hue: 260, videoId: '' },
  { id: 's3', title: 'Neon Coastline', artist: 'Vela Cruz', duration: 231, hue: 200, videoId: '' },
  { id: 's4', title: 'Low Tide', artist: 'Marina Shore', duration: 198, hue: 340, videoId: '' },
  { id: 's5', title: 'Glass City', artist: 'Halcyon Ray', duration: 246, hue: 40, videoId: '' },
  { id: 's6', title: 'Afterglow', artist: 'Dune Runner', duration: 176, hue: 15, videoId: '' },
]

export const playlists: Playlist[] = [
  {
    id: 'favorites',
    name: 'My Favourites',
    cover: null,
    hue: 335,
    songIds: ['s1', 's5'],
    ownerIdentifier: currentUser.identifier,
    ownerName: currentUser.name,
    collaborators: [],
    isDefault: true,
  },
  {
    id: 'p1',
    name: 'Late Night Cruising',
    cover: null,
    hue: 172,
    songIds: ['s1', 's3', 's6'],
    ownerIdentifier: currentUser.identifier,
    ownerName: currentUser.name,
    collaborators: [{ identifier: otherUsers[0].identifier, name: otherUsers[0].name }],
  },
  {
    id: 'p2',
    name: 'Chill Garage Vibes',
    cover: null,
    hue: 265,
    songIds: ['s2', 's5'],
    ownerIdentifier: currentUser.identifier,
    ownerName: currentUser.name,
    collaborators: [],
  },
]
