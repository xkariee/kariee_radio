const pad = (n: number) => n.toString().padStart(2, '0')

export const clamp = (value: number, min = 0, max = 1) => Math.min(max, Math.max(min, value))

export function plural(count: number, word: string): string {
  return `${count} ${word}${count === 1 ? '' : 's'}`
}

export function formatTime(seconds: number): string {
  const total = Math.max(0, Math.floor(seconds))
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  return h ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`
}

export function formatLength(seconds: number): string {
  const minutes = Math.round(seconds / 60)
  if (minutes < 60) return `${minutes} min`
  const h = Math.floor(minutes / 60)
  const m = minutes % 60
  return m ? `${h} hr ${m} min` : `${h} hr`
}

export function formatDistance(meters?: number | null): string {
  if (meters == null || !isFinite(meters)) return '—'
  if (meters < 1000) return `${Math.round(meters)} m`
  return `${(meters / 1000).toFixed(meters < 10_000 ? 1 : 0)} km`
}

export function toMs(t?: number | null): number | null {
  if (t == null || !isFinite(t)) return null
  return t < 1e11 ? t * 1000 : t
}

export function relativeTime(t: number | null | undefined, nowMs: number): string {
  const ms = toMs(t)
  if (ms == null) return '—'
  const diff = Math.round((ms - nowMs) / 1000)
  const abs = Math.abs(diff)
  if (abs < 45) return diff >= 0 ? 'in a moment' : 'just now'

  let text: string
  if (abs < 3600) text = `${Math.round(abs / 60)} min`
  else if (abs < 86400) text = `${Math.round(abs / 3600)} hr`
  else text = `${Math.round(abs / 86400)} ${abs < 172800 ? 'day' : 'days'}`
  return diff >= 0 ? `in ${text}` : `${text} ago`
}

export function clockTime(t: number | null | undefined): string {
  const ms = toMs(t)
  return ms == null ? '—' : new Date(ms).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })
}

export function shortDate(t: number | null | undefined): string {
  const ms = toMs(t)
  return ms == null ? '—' : new Date(ms).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })
}

export function matchesQuery(query: string, values: unknown[]): boolean {
  const needle = query.trim().toLowerCase()
  return !needle || values.some((value) => value != null && String(value).toLowerCase().includes(needle))
}

export function byDistance(a: { distance?: number }, b: { distance?: number }): number {
  return (a.distance ?? Infinity) - (b.distance ?? Infinity)
}

export function asArray<T>(value: unknown): T[] {
  if (Array.isArray(value)) return value as T[]
  if (value && typeof value === 'object') return Object.values(value) as T[]
  return []
}

export function shuffled<T>(list: T[]): T[] {
  const out = [...list]
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[out[i], out[j]] = [out[j], out[i]]
  }
  return out
}
