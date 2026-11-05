const PREFIX = 'kariee_radio:'

function read(key: string): unknown {
  try {
    const raw = localStorage.getItem(PREFIX + key)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export function loadJson<T extends object>(key: string, fallback: T): T {
  const saved = read(key)
  return saved && typeof saved === 'object' ? { ...fallback, ...saved } : fallback
}

export function loadList(key: string): string[] {
  const saved = read(key)
  return Array.isArray(saved) ? saved.filter((item): item is string => typeof item === 'string') : []
}

export function saveJson(key: string, value: unknown) {
  try {
    localStorage.setItem(PREFIX + key, JSON.stringify(value))
  } catch {
    return
  }
}
