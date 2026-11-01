// NUI localStorage survives game restarts, but can still throw or come back empty - every
// read/write here degrades to "use the defaults" instead of breaking the UI.

const PREFIX = 'kariee_radio:'

export function loadJson<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(PREFIX + key)
    return raw ? { ...fallback, ...JSON.parse(raw) } : fallback
  } catch {
    return fallback
  }
}

export function loadList(key: string): string[] {
  try {
    const parsed = JSON.parse(localStorage.getItem(PREFIX + key) ?? '[]')
    return Array.isArray(parsed) ? parsed.filter((x) => typeof x === 'string') : []
  } catch {
    return []
  }
}

export function saveJson(key: string, value: unknown) {
  try {
    localStorage.setItem(PREFIX + key, JSON.stringify(value))
  } catch {
    // storage full or blocked - settings just won't persist this session
  }
}
