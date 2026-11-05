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
const pendingVolumes = new Map<string, number>()
let apiPromise: Promise<void> | null = null

const hostId = (id: string) => `yt-host-${id}`

function loadIframeApi(): Promise<void> {
  apiPromise ??= new Promise((resolve) => {
    if (window.YT?.Player) return resolve()
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
  const elementId = hostId(id)
  if (!document.getElementById(elementId)) {
    const el = document.createElement('div')
    el.id = elementId
    el.style.cssText = 'position:fixed;width:1px;height:1px;overflow:hidden;opacity:0;pointer-events:none;'
    document.body.appendChild(el)
  }
  return elementId
}

async function ensurePlayer(id: string): Promise<Entry> {
  const existing = players.get(id)
  if (existing) return existing

  await loadIframeApi()
  const entry: Entry = { player: null, ready: false, pendingVolume: pendingVolumes.get(id) ?? 0 }
  pendingVolumes.delete(id)
  players.set(id, entry)

  entry.player = new window.YT.Player(ensureHost(id), {
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

function readyPlayer(id: string) {
  const entry = players.get(id)
  return entry?.ready ? entry.player : null
}

export async function play(id: string, videoId: string, startSeconds = 0) {
  const entry = await ensurePlayer(id)
  if (entry.ready) {
    entry.player.loadVideoById({ videoId, startSeconds })
  } else {
    entry.pendingVideoId = videoId
    entry.pendingStart = startSeconds
  }
}

export function pause(id: string) {
  readyPlayer(id)?.pauseVideo()
}

export function resume(id: string) {
  readyPlayer(id)?.playVideo()
}

export function seek(id: string, seconds: number) {
  readyPlayer(id)?.seekTo(seconds, true)
}

export function setVolume(id: string, volume: number) {
  const percent = Math.round(Math.max(0, Math.min(1, volume)) * 100)
  const entry = players.get(id)
  if (!entry) pendingVolumes.set(id, percent)
  else if (entry.ready) entry.player.setVolume(percent)
  else entry.pendingVolume = percent
}

export function destroy(id: string) {
  players.get(id)?.player?.destroy?.()
  players.delete(id)
  pendingVolumes.delete(id)
  endedHandlers.delete(id)
  document.getElementById(hostId(id))?.remove()
}

export function onEnded(id: string, cb: () => void) {
  endedHandlers.set(id, cb)
}

export function getPosition(id: string): { time: number; playing: boolean } | null {
  const entry = players.get(id)
  if (!entry?.ready || entry.pendingVideoId || typeof entry.player.getPlayerState !== 'function') return null
  const playerState = entry.player.getPlayerState()
  if (playerState === window.YT.PlayerState.UNSTARTED) return null
  return { time: Number(entry.player.getCurrentTime()) || 0, playing: playerState === window.YT.PlayerState.PLAYING }
}
