// Small display helpers shared by the admin panel and the nearby widget.

export function formatDistance(m?: number | null): string {
  if (m == null || !isFinite(m)) return '—'
  if (m < 1000) return `${Math.round(m)} m`
  return `${(m / 1000).toFixed(m < 10_000 ? 1 : 0)} km`
}

// Accepts unix seconds or ms (oxmysql returns TIMESTAMP columns as ms).
export function toMs(t?: number | null): number | null {
  if (t == null || !isFinite(t)) return null
  return t < 1e11 ? t * 1000 : t
}

export function relativeTime(t: number | null | undefined, nowMs: number): string {
  const ms = toMs(t)
  if (ms == null) return '—'
  const diff = Math.round((ms - nowMs) / 1000)
  const abs = Math.abs(diff)
  const unit =
    abs < 45
      ? null
      : abs < 3600
        ? ([Math.round(abs / 60), 'min'] as const)
        : abs < 86400
          ? ([Math.round(abs / 3600), 'hr'] as const)
          : ([Math.round(abs / 86400), abs < 172800 ? 'day' : 'days'] as const)
  if (!unit) return diff >= 0 ? 'in a moment' : 'just now'
  const text = `${unit[0]} ${unit[1]}`
  return diff >= 0 ? `in ${text}` : `${text} ago`
}

export function clockTime(t: number | null | undefined): string {
  const ms = toMs(t)
  if (ms == null) return '—'
  // Fixed English locale so dates match the rest of the (English) UI on any Windows language.
  return new Date(ms).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })
}

export function shortDate(t: number | null | undefined): string {
  const ms = toMs(t)
  if (ms == null) return '—'
  return new Date(ms).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })
}

// Lua serialises an empty table as {} rather than [] - normalise anything list-like.
export function asArray<T>(v: unknown): T[] {
  if (Array.isArray(v)) return v as T[]
  if (v && typeof v === 'object') return Object.values(v) as T[]
  return []
}
