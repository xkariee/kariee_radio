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

// A DJ booth "in range", so the nearby now-playing widget shows when the panel is closed in dev.
export const devLiveBroadcast = {
  id: 'dj:1',
  kind: 'dj' as const,
  label: 'DJ booth · Vinewood Blvd',
  owner: 31,
  song: songs[6],
  playing: true,
  progress: 48,
}

const toServerSong = (s: Song) => ({
  songId: s.id,
  title: s.title,
  artist: s.artist,
  duration: s.duration,
  videoId: s.videoId || 'dev' + s.id,
  thumbnail: null,
  hue: s.hue,
})

// Same shape server/admin.lua + client/admin.lua return for `adminGetData`.
export function devAdminData() {
  const now = Math.floor(Date.now() / 1000)
  return {
    now,
    me: 7,
    nearbyRadius: 50,
    broadcasts: [
      {
        id: 'dj:1', kind: 'dj', label: 'DJ booth · Vinewood Blvd', stationId: 1, playing: true, volume: 85,
        progress: 48, song: toServerSong(songs[6]), queueLength: 6, ownerId: 31, ownerName: 'Drex Monroe',
        ownerIdentifier: 'char1:drex', startedAt: now - 48, coords: { x: 120, y: -1280, z: 29 },
        street: 'Vinewood Blvd', zone: 'Downtown Vinewood', distance: 34, interior: true, nearbyPlayers: 9,
      },
      {
        id: 'radio:12', kind: 'radio', label: 'Personal radio', playing: true, volume: 100, progress: 131,
        song: toServerSong(songs[7]), queueLength: 0, ownerId: 12, ownerName: 'Skyla Reyes', ownerIdentifier: 'char1:skyla',
        startedAt: now - 131, coords: { x: 180, y: -1300, z: 29 }, street: 'Power St', zone: 'Pillbox Hill',
        distance: 46, interior: false, nearbyPlayers: 3,
      },
      {
        id: 'car:2201', kind: 'radiocar', label: 'Car radio', playing: true, volume: 70, progress: 12,
        song: toServerSong(songs[9]), queueLength: 3, ownerId: 47, ownerName: 'Mako Tanaka', ownerIdentifier: 'char1:mako',
        startedAt: now - 12, coords: { x: 900, y: -200, z: 70 }, street: 'Great Ocean Hwy', zone: 'Chumash',
        distance: 2140, interior: false, nearbyPlayers: 1,
      },
      {
        id: 'dj:3', kind: 'dj', label: 'DJ booth · Del Perro Pier', stationId: 3, playing: false, volume: 60,
        progress: 75, song: toServerSong(songs[10]), queueLength: 0, ownerId: 58, ownerName: 'Lena Voss',
        ownerIdentifier: 'char1:lena', startedAt: now - 600, coords: { x: -1600, y: -1000, z: 13 },
        street: 'Del Perro Pier', zone: 'Del Perro Beach', distance: 1890, interior: false, nearbyPlayers: 0,
      },
    ],
    stations: [
      {
        id: 1, label: 'DJ booth · Vinewood Blvd', ownerIdentifier: 'char1:drex', ownerName: 'Drex Monroe',
        createdAt: Date.now() - 9 * 86400_000, broadcastId: 'dj:1', playing: true, song: toServerSong(songs[6]),
        coords: { x: 120, y: -1280, z: 29 }, street: 'Vinewood Blvd', zone: 'Downtown Vinewood', distance: 34, interior: true,
      },
      {
        id: 2, label: 'Bahama Mamas main room', ownerIdentifier: 'dev:local', ownerName: 'Kariee',
        createdAt: Date.now() - 30 * 86400_000, broadcastId: 'dj:2', playing: false, song: null,
        coords: { x: -1390, y: -600, z: 30 }, street: 'Marathon Ave', zone: 'Del Perro', distance: 1410, interior: true,
      },
      {
        id: 3, label: 'DJ booth · Del Perro Pier', ownerIdentifier: 'char1:lena', ownerName: 'Lena Voss',
        createdAt: Date.now() - 2 * 86400_000, broadcastId: 'dj:3', playing: false, song: toServerSong(songs[10]),
        coords: { x: -1600, y: -1000, z: 13 }, street: 'Del Perro Pier', zone: 'Del Perro Beach', distance: 1890, interior: false,
      },
    ],
    bans: [
      {
        identifier: 'char1:rico', name: 'Rico Vance', scope: 'dj', reason: 'Earrape at the pier booth',
        bannedBy: 'Kariee', expiresAt: now + 2 * 86400, createdAt: now - 3600, online: true,
      },
      {
        identifier: 'char1:zed', name: 'Zed', scope: 'all', reason: 'Repeated harassment through music',
        bannedBy: 'Kariee', expiresAt: null, createdAt: now - 12 * 86400, online: false,
      },
    ],
    players: [
      { id: 7, name: 'Kariee', identifier: 'dev:local' },
      { id: 12, name: 'Skyla Reyes', identifier: 'char1:skyla' },
      { id: 31, name: 'Drex Monroe', identifier: 'char1:drex' },
      { id: 47, name: 'Mako Tanaka', identifier: 'char1:mako' },
      { id: 58, name: 'Lena Voss', identifier: 'char1:lena' },
      { id: 64, name: 'Rico Vance', identifier: 'char1:rico' },
    ],
    activity: [
      { t: now - 12, action: 'play', detail: '“Concrete Heat” by Kilo Static', actor: 'Mako Tanaka', actorId: 47, identifier: 'char1:mako', kind: 'radiocar', label: 'Car radio' },
      { t: now - 48, action: 'play', detail: '“Vinewood Lights” by The Palomino Set', actor: 'Drex Monroe', actorId: 31, identifier: 'char1:drex', kind: 'dj', label: 'DJ booth · Vinewood Blvd' },
      { t: now - 131, action: 'play', detail: '“Redline” by Kilo Static', actor: 'Skyla Reyes', actorId: 12, identifier: 'char1:skyla', kind: 'radio', label: 'Personal radio' },
      { t: now - 3600, action: 'ban', detail: 'Banned Rico Vance from DJ booths (2 days): Earrape at the pier booth', actor: 'Kariee', actorId: 7, target: 'Rico Vance', targetIdentifier: 'char1:rico' },
      { t: now - 3700, action: 'admin_stop', detail: 'Stopped “Bass Boosted Siren” on DJ booth · Del Perro Pier', actor: 'Kariee', actorId: 7, kind: 'dj', target: 'Rico Vance' },
      { t: now - 3900, action: 'play', detail: '“Bass Boosted Siren” by xX_Rico_Xx', actor: 'Rico Vance', actorId: 64, identifier: 'char1:rico', kind: 'dj', label: 'DJ booth · Del Perro Pier' },
      { t: now - 2 * 86400, action: 'booth_created', detail: 'Placed booth #3 “DJ booth · Del Perro Pier”', actor: 'Lena Voss', actorId: 58 },
    ],
  }
}

export const invites: Invite[] = [
  { playlistId: 'p9', name: 'Rooftop Sessions', hue: 28, invitedBy: 'dev:mako', invitedByName: 'Mako' },
]
