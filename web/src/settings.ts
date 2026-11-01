import { reactive, watch } from 'vue'
import { loadJson, saveJson } from './utils/persist'

export type AccentChoice = 'adaptive' | 'custom' | 'rose' | 'mint' | 'teal' | 'violet' | 'amber' | 'sky'

export interface Settings {
  accent: AccentChoice
  // Hex the player picked for the 'custom' accent.
  customAccent: string
  // User multiplier on top of the automatic resolution scale (1080p = 1.0).
  scale: number
  density: 'comfortable' | 'compact'
  reduceMotion: boolean
  highContrast: boolean
  ambient: boolean
  showRemaining: boolean
  nowPlayingPanel: boolean
}

export const ACCENT_HUES: Record<Exclude<AccentChoice, 'adaptive' | 'custom'>, number> = {
  rose: 336,
  mint: 146,
  teal: 172,
  violet: 262,
  amber: 36,
  sky: 204,
}

// Shown while nothing is playing in adaptive mode.
export const DEFAULT_HUE = ACCENT_HUES.rose

const prefersReducedMotion =
  typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches

export const defaultSettings: Settings = {
  accent: 'adaptive',
  customAccent: '#ff6aa7',
  scale: 1,
  density: 'comfortable',
  reduceMotion: !!prefersReducedMotion,
  highContrast: false,
  ambient: true,
  showRemaining: false,
  nowPlayingPanel: true,
}

export const settings = reactive<Settings>(loadJson('settings', defaultSettings))

export function resetSettings() {
  Object.assign(settings, defaultSettings)
}

watch(settings, () => saveJson('settings', settings), { deep: true })

// ─── Theme ─────────────────────────────────────────────────────────────────

type Rgb = [number, number, number]

function hslToRgb(h: number, s: number, l: number): Rgb {
  const k = (n: number) => (n + h / 30) % 12
  const a = s * Math.min(l, 1 - l)
  const f = (n: number) => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)))
  return [Math.round(f(0) * 255), Math.round(f(8) * 255), Math.round(f(4) * 255)]
}

function luminance([r, g, b]: Rgb) {
  const c = [r, g, b].map((v) => {
    const s = v / 255
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
  })
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
}

function contrast(a: Rgb, b: Rgb) {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x)
  return (hi + 0.05) / (lo + 0.05)
}

const hex = (rgb: Rgb) => '#' + rgb.map((v) => v.toString(16).padStart(2, '0')).join('')
const rgba = ([r, g, b]: Rgb, a: number) => `rgba(${r}, ${g}, ${b}, ${a})`

export function hexToHsl(value: string): [number, number, number] | null {
  const m = /^#?([0-9a-f]{6})$/i.exec(value.trim())
  if (!m) return null
  const n = parseInt(m[1], 16)
  const [r, g, b] = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((c) => c / 255)
  const max = Math.max(r, g, b)
  const min = Math.min(r, g, b)
  const l = (max + min) / 2
  if (max === min) return [0, 0, l]
  const d = max - min
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
  const h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4
  return [h * 60, s, l]
}

// Darkest surface an accent ever sits on - every accent is lifted until it clears AA+ against it,
// so song-driven hues (deep blues especially) or a too-dark custom pick never drop below
// readable contrast. Colours that are already light enough are left as chosen.
const PANEL: Rgb = [23, 21, 27]

export function accentPalette(hue: number, sat = 0.85, startL = 0.6) {
  let l = startL
  let rgb = hslToRgb(hue, sat, l)
  while (contrast(rgb, PANEL) < 6.2 && l < 0.9) {
    l += 0.02
    rgb = hslToRgb(hue, sat, l)
  }
  return {
    '--accent': hex(rgb),
    '--accent-strong': hex(hslToRgb(hue, Math.min(1, sat + 0.1), Math.min(0.94, l + 0.1))),
    '--accent-deep': hex(hslToRgb(hue, sat * 0.53, 0.2)),
    '--accent-soft': rgba(rgb, 0.14),
    '--accent-line': rgba(rgb, 0.42),
    '--accent-glow': rgba(rgb, 0.38),
  }
}

// A hue (theme presets / adaptive song colour) or any hex (custom pick).
export type AccentSource = number | string

export function paletteFor(src: AccentSource) {
  if (typeof src === 'number') return accentPalette(src)
  const hsl = hexToHsl(src)
  return hsl ? accentPalette(hsl[0], hsl[1], hsl[2]) : accentPalette(DEFAULT_HUE)
}

export function applyAccent(src: AccentSource) {
  const root = document.documentElement.style
  for (const [k, v] of Object.entries(paletteFor(src))) root.setProperty(k, v)
}

// 1rem = 10px at 1080p and 100%, so every size in the stylesheet scales together with the
// player's resolution (4K NUI is otherwise tiny) and their own preference.
export function applyScale() {
  const auto = Math.min(window.innerHeight / 1080, window.innerWidth / 1600)
  const base = Math.max(0.75, Math.min(2.4, auto))
  document.documentElement.style.fontSize = `${(10 * base * settings.scale).toFixed(3)}px`
}

export function applyFlags() {
  const cl = document.documentElement.classList
  cl.toggle('reduce-motion', settings.reduceMotion)
  cl.toggle('high-contrast', settings.highContrast)
  cl.toggle('density-compact', settings.density === 'compact')
}
