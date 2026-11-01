declare global {
  interface Window {
    GetParentResourceName?: () => string
  }
}

export const isNuiEnv = typeof window.GetParentResourceName === 'function'

const resourceName = isNuiEnv ? window.GetParentResourceName!() : 'kariee_radio'

// Plain-browser `npm run dev` has no game to answer callbacks - these stand in for the few
// responses the UI actually reads, so playlist/invite flows can still be clicked through.
const devResponses: Record<string, (data: any) => unknown> = {
  createPlaylist: (d) => ({
    id: `dev-${Date.now()}`,
    name: d.name,
    cover: d.cover,
    hue: Math.floor(Math.random() * 360),
    owner_identifier: 'dev:local',
    owner_name: 'You',
    collaborators: [],
    tracks: [],
  }),
  searchPlayers: (d) =>
    [
      { id: 12, name: 'Skyla Reyes' },
      { id: 31, name: 'Drex Monroe' },
      { id: 47, name: 'Mako Tanaka' },
      { id: 58, name: 'Lena Voss' },
    ].filter((p) => p.name.toLowerCase().includes(String(d.query ?? '').toLowerCase())),
}

export async function fetchNui<T = any>(event: string, data: unknown = {}): Promise<T> {
  if (!isNuiEnv) return (devResponses[event]?.(data) ?? null) as T

  const resp = await fetch(`https://${resourceName}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  })
  return resp.json() as Promise<T>
}

type MessageHandler = (data: any) => void
const listeners = new Map<string, Set<MessageHandler>>()

export function onNuiMessage(action: string, handler: MessageHandler): () => void {
  if (!listeners.has(action)) listeners.set(action, new Set())
  listeners.get(action)!.add(handler)
  return () => listeners.get(action)?.delete(handler)
}

window.addEventListener('message', (event: MessageEvent) => {
  const action = event.data?.action
  if (!action) return
  listeners.get(action)?.forEach((handler) => handler(event.data))
})
