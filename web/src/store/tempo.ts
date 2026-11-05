import { computed } from 'vue'
import type { Tempo } from '../types'
import * as audioEngine from '../services/audioEngine'
import { fetchNui, isNuiEnv } from '../services/nui'
import { session, state } from './state'
import { controlLocked, currentSong } from './player'

const TAP_RESET_MS = 2000
const COMMIT_DELAY_MS = 700
const MIN_TAPS = 4
const MIN_BPM = 60
const MAX_BPM = 200

let taps: { wall: number; song: number }[] = []
let tapReset: ReturnType<typeof setTimeout> | null = null
let commitTimer: ReturnType<typeof setTimeout> | null = null

export const lightSync = computed(() => state.lightsEnabled && (state.contextKind === 'dj' || !isNuiEnv) && !!currentSong.value)

export function isTempoPending() {
  return commitTimer !== null
}

function songTimeNow(): number {
  const position = session.broadcastId ? audioEngine.getPosition(session.broadcastId) : null
  return position ? position.time : state.progress
}

function setTempo(tempo: Tempo | null) {
  if (controlLocked()) return
  state.tempo = tempo
  if (commitTimer) clearTimeout(commitTimer)
  commitTimer = setTimeout(() => {
    commitTimer = null
    fetchNui('setTempo', tempo ?? {})
  }, COMMIT_DELAY_MS)
}

function bpmFromTaps(): number | null {
  const n = taps.length
  const meanIndex = (n - 1) / 2
  const meanWall = taps.reduce((sum, tap) => sum + tap.wall, 0) / n
  let num = 0
  let den = 0
  taps.forEach((tap, i) => {
    num += (i - meanIndex) * (tap.wall - meanWall)
    den += (i - meanIndex) ** 2
  })

  let bpm = 60000 / (num / den)
  if (!Number.isFinite(bpm) || bpm <= 0) return null
  while (bpm > MAX_BPM) bpm /= 2
  while (bpm < MIN_BPM) bpm *= 2
  return Math.round(bpm)
}

export function tapTempo() {
  if (!lightSync.value || !state.isPlaying || controlLocked()) return
  const wall = performance.now()
  if (taps.length && wall - taps[taps.length - 1].wall > TAP_RESET_MS) taps = []
  taps.push({ wall, song: songTimeNow() })
  state.tapCount = taps.length
  if (tapReset) clearTimeout(tapReset)
  tapReset = setTimeout(() => (state.tapCount = 0), TAP_RESET_MS)

  if (taps.length === 1) {
    if (state.tempo) setTempo({ bpm: state.tempo.bpm, offset: taps[0].song })
    return
  }
  if (taps.length < MIN_TAPS) return

  const bpm = bpmFromTaps()
  if (!bpm) return
  const beat = 60 / bpm
  const offset = taps.reduce((sum, tap, i) => sum + (tap.song - i * beat), 0) / taps.length
  setTempo({ bpm, offset })
}

export function nudgeTempo(delta: number) {
  const tempo = state.tempo
  if (!tempo) return
  const bpm = Math.min(MAX_BPM, Math.max(MIN_BPM, tempo.bpm + delta))
  const now = songTimeNow()
  const beats = ((now - tempo.offset) * tempo.bpm) / 60
  setTempo({ bpm, offset: now - (beats * 60) / bpm })
}

export function resetTempo() {
  taps = []
  state.tapCount = 0
  setTempo(null)
}
