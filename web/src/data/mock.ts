import type { Invite, Song, Playlist } from '../types'

// Only used when running `npm run dev` in a plain browser (no GetParentResourceName), so the UI
// can still be iterated on standalone. None of this is real playable media or real identifiers.

export const currentUser = { identifier: 'dev:local', name: 'Kariee' }

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
  { id: 's7', title: 'Vinewood Lights', artist: 'The Palomino Set', duration: 203, hue: 300, videoId: '' },
  { id: 's8', title: 'Redline', artist: 'Kilo Static', duration: 167, hue: 0, videoId: '' },
  { id: 's9', title: 'Paleto Mornings', artist: 'Marina Shore', duration: 252, hue: 120, videoId: '' },
  { id: 's10', title: 'Concrete Heat', artist: 'Kilo Static', duration: 188, hue: 24, videoId: '' },
  { id: 's11', title: 'Del Perro Pier', artist: 'Dune Runner', duration: 221, hue: 190, videoId: '' },
  { id: 's12', title: 'Satellite Hearts', artist: 'Halcyon Ray', duration: 239, hue: 280, videoId: '' },
]

export const recentlyPlayedIds = ['s3', 's7', 's1', 's10', 's4', 's12', 's9', 's2']

export const playlists: Playlist[] = [
  {
    id: 'favorites',
    name: 'Liked Songs',
    cover: null,
    hue: 335,
    songIds: ['s1', 's5', 's7', 's12'],
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
    songIds: ['s1', 's3', 's6', 's11', 's9'],
    ownerIdentifier: currentUser.identifier,
    ownerName: currentUser.name,
    collaborators: [
      { identifier: otherUsers[0].identifier, name: otherUsers[0].name },
      { identifier: otherUsers[1].identifier, name: otherUsers[1].name },
    ],
  },
  {
    id: 'p2',
    name: 'Chill Garage Vibes',
    cover: null,
    hue: 265,
    songIds: ['s2', 's5', 's12'],
    ownerIdentifier: currentUser.identifier,
    ownerName: currentUser.name,
    collaborators: [],
  },
  {
    id: 'p3',
    name: 'Grove Street Heat',
    cover: null,
    hue: 24,
    songIds: ['s8', 's10', 's6', 's7'],
    ownerIdentifier: otherUsers[2].identifier,
    ownerName: otherUsers[2].name,
    collaborators: [{ identifier: currentUser.identifier, name: currentUser.name }],
  },
]

export const invites: Invite[] = [
  { playlistId: 'p9', name: 'Rooftop Sessions', hue: 28, invitedBy: 'dev:mako', invitedByName: 'Mako' },
]
