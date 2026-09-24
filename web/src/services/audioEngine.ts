// Pool of hidden YouTube iframe players, one per active broadcast id (yours + everyone/everything
// audible around you). Volume for each is driven independently by client/broadcast.lua's
// distance/interior calculation, pushed in over the NUI bridge - this module only knows how to
// play/pause/seek/volume a given id, not why.

declare global {
  interface Window {
    YT: any
    onYouTubeIframeAPIReady?: () => void
  }
}

interface Entry {
  player: any
  ready: boolean
  pendingVideoId?: string
  pendingStart?: number
  pendingVolume?: number
}

const players = new Map<string, Entry>()
const endedHandlers = new Map<string, () => void>()
// Volume updates that arrived before ensurePlayer() finished creating the entry (the very first
// YouTube iframe API load in particular can take a while) - without this they'd be silently
// dropped, leaving the player stuck at YouTube's default 100% volume forever.
const pendingVolumeById = new Map<string, number>()
let apiPromise: Promise<void> | null = null

function loadIframeApi(): Promise<void> {
  if (apiPromise) return apiPromise
  apiPromise = new Promise((resolve) => {
    if (window.YT?.Player) {
      resolve()
      return
    }
    const tag = document.createElement('script')
    tag.src = 'https://www.youtube.com/iframe_api'
    document.head.appendChild(tag)
    const previous = window.onYouTubeIframeAPIReady
    window.onYouTubeIframeAPIReady = () => {
      previous?.()
      resolve()
    }
  })
  return apiPromise
}

function ensureHost(id: string): string {
  const hostId = `yt-host-${id}`
  if (!document.getElementById(hostId)) {
    const el = document.createElement('div')
    el.id = hostId
    el.style.cssText = 'position:fixed;width:1px;height:1px;overflow:hidden;opacity:0;pointer-events:none;'
    document.body.appendChild(el)
  }
  return hostId
}

async function ensurePlayer(id: string): Promise<Entry> {
  const existing = players.get(id)
  if (existing) return existing

  await loadIframeApi()
  const hostId = ensureHost(id)
  // Default to silent rather than trusting YouTube's 100% default - safer to fail quiet than loud.
  const entry: Entry = { player: null, ready: false, pendingVolume: pendingVolumeById.get(id) ?? 0 }
  pendingVolumeById.delete(id)
  players.set(id, entry)

  entry.player = new window.YT.Player(hostId, {
    height: '0',
    width: '0',
    playerVars: { playsinline: 1, controls: 0, disablekb: 1, modestbranding: 1 },
    events: {
      onReady: () => {
        entry.ready = true
        if (entry.pendingVideoId) {
          entry.player.loadVideoById({ videoId: entry.pendingVideoId, startSeconds: entry.pendingStart ?? 0 })
          entry.pendingVideoId = undefined
        }
        if (entry.pendingVolume !== undefined) {
          entry.player.setVolume(entry.pendingVolume)
          entry.pendingVolume = undefined
        }
      },
      onStateChange: (e: { data: number }) => {
        if (e.data === window.YT.PlayerState.ENDED) endedHandlers.get(id)?.()
      },
    },
  })

  return entry
}

export async function play(id: string, videoId: string, startSeconds = 0) {
  const entry = await ensurePlayer(id)
  if (entry.ready) entry.player.loadVideoById({ videoId, startSeconds })
  else {
    entry.pendingVideoId = videoId
    entry.pendingStart = startSeconds
  }
}

export function pause(id: string) {
  const entry = players.get(id)
  if (entry?.ready) entry.player.pauseVideo()
}

export function resume(id: string) {
  const entry = players.get(id)
  if (entry?.ready) entry.player.playVideo()
}

export function seek(id: string, seconds: number) {
  const entry = players.get(id)
  if (entry?.ready) entry.player.seekTo(seconds, true)
}

export function setVolume(id: string, volume0to1: number) {
  const vol = Math.round(Math.max(0, Math.min(1, volume0to1)) * 100)
  const entry = players.get(id)
  if (!entry) {
    // No player yet (still being created, or hasn't been told to play anything) - remember it so
    // ensurePlayer() can apply it as soon as the entry exists, instead of dropping it silently.
    pendingVolumeById.set(id, vol)
    return
  }
  if (entry.ready) entry.player.setVolume(vol)
  else entry.pendingVolume = vol
}

export function destroy(id: string) {
  const entry = players.get(id)
  if (entry?.player?.destroy) entry.player.destroy()
  players.delete(id)
  pendingVolumeById.delete(id)
  endedHandlers.delete(id)
  document.getElementById(`yt-host-${id}`)?.remove()
}

export function onEnded(id: string, cb: () => void) {
  endedHandlers.set(id, cb)
}

export function getCurrentTime(id: string): number {
  const entry = players.get(id)
  return entry?.ready ? entry.player.getCurrentTime() : 0
}
