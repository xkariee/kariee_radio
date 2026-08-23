declare global {
  interface Window {
    YT: any
    onYouTubeIframeAPIReady?: () => void
  }
}

interface PlayerHandlers {
  onReady?: () => void
  onEnded?: () => void
  onProgress?: (seconds: number) => void
}

let player: any = null
let apiPromise: Promise<void> | null = null
let progressTimer: ReturnType<typeof setInterval> | null = null
let handlers: PlayerHandlers = {}

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
    window.onYouTubeIframeAPIReady = () => resolve()
  })
  return apiPromise
}

function startProgressPoll() {
  stopProgressPoll()
  progressTimer = setInterval(() => {
    if (player?.getCurrentTime) handlers.onProgress?.(player.getCurrentTime())
  }, 500)
}

function stopProgressPoll() {
  if (progressTimer) clearInterval(progressTimer)
  progressTimer = null
}

export async function initPlayer(elementId: string, h: PlayerHandlers) {
  handlers = h
  await loadIframeApi()
  const YT = window.YT
  player = new YT.Player(elementId, {
    height: '0',
    width: '0',
    playerVars: { playsinline: 1, controls: 0, disablekb: 1, modestbranding: 1 },
    events: {
      onReady: () => handlers.onReady?.(),
      onStateChange: (e: { data: number }) => {
        if (e.data === YT.PlayerState.PLAYING) startProgressPoll()
        else stopProgressPoll()
        if (e.data === YT.PlayerState.ENDED) handlers.onEnded?.()
      },
    },
  })
}

export function playVideo(videoId: string) {
  player?.loadVideoById(videoId)
}

export function play() {
  player?.playVideo()
}

export function pause() {
  player?.pauseVideo()
}

export function seekTo(seconds: number) {
  player?.seekTo(seconds, true)
}

export function setVolume(volume: number) {
  player?.setVolume(volume)
}

export function mute() {
  player?.mute()
}

export function unmute() {
  player?.unMute()
}

export function getDuration(): number {
  return player?.getDuration?.() ?? 0
}
