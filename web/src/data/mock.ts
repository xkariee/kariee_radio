import type { Song, Playlist, User } from '../types'

export const currentUser: User = { id: 'u0', name: 'You', color: '#2dd4bf' }

export const mockUsers: User[] = [
  currentUser,
  { id: 'u1', name: 'Skyla', color: '#f472b6' },
  { id: 'u2', name: 'Drex', color: '#60a5fa' },
  { id: 'u3', name: 'Mako', color: '#fbbf24' },
  { id: 'u4', name: 'Ren', color: '#a78bfa' },
  { id: 'u5', name: 'Tovi', color: '#fb923c' },
]

export const songs: Song[] = [
  { id: 's1', title: 'Night Drive', artist: 'Vela Cruz', duration: 214, hue: 172, source: 'local' },
  { id: 's2', title: 'Static Bloom', artist: 'Halcyon Ray', duration: 189, hue: 260, source: 'local' },
  { id: 's3', title: 'Neon Coastline', artist: 'Vela Cruz', duration: 231, hue: 200, source: 'local' },
  { id: 's4', title: 'Low Tide', artist: 'Marina Shore', duration: 198, hue: 340, source: 'local' },
  { id: 's5', title: 'Glass City', artist: 'Halcyon Ray', duration: 246, hue: 40, source: 'local' },
  { id: 's6', title: 'Afterglow', artist: 'Dune Runner', duration: 176, hue: 15, source: 'local' },
  { id: 's7', title: 'Echo Chamber', artist: 'Marina Shore', duration: 203, hue: 285, source: 'local' },
  { id: 's8', title: 'Velvet Static', artist: 'Nova West', duration: 220, hue: 172, source: 'local' },
  { id: 's9', title: 'Skyline Fade', artist: 'Dune Runner', duration: 191, hue: 210, source: 'local' },
  { id: 's10', title: 'Paper Moon', artist: 'Nova West', duration: 235, hue: 55, source: 'local' },
  { id: 's11', title: 'Backroad', artist: 'Vela Cruz', duration: 168, hue: 320, source: 'local' },
  { id: 's12', title: 'Amber Rooms', artist: 'Halcyon Ray', duration: 227, hue: 25, source: 'local' },
]

export const playlists: Playlist[] = [
  {
    id: 'favorites',
    name: 'My Favourites',
    cover: null,
    hue: 335,
    songIds: ['s1', 's5'],
    ownerId: 'u0',
    collaboratorIds: [],
    isDefault: true,
  },
  {
    id: 'p1',
    name: 'Late Night Cruising',
    cover: null,
    hue: 172,
    songIds: ['s1', 's3', 's6', 's9', 's11'],
    ownerId: 'u0',
    collaboratorIds: ['u1'],
  },
  {
    id: 'p2',
    name: 'Chill Garage Vibes',
    cover: null,
    hue: 265,
    songIds: ['s2', 's5', 's8', 's12'],
    ownerId: 'u0',
    collaboratorIds: [],
  },
  {
    id: 'p3',
    name: 'Heist Prep',
    cover: null,
    hue: 20,
    songIds: ['s4', 's7', 's10'],
    ownerId: 'u2',
    collaboratorIds: ['u0', 'u3'],
  },
]
