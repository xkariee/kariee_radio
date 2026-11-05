import { devAdminData, devPlayers } from '../data/mock'

declare global {
  interface Window {
    GetParentResourceName?: () => string
  }
}

type MessageHandler = (data: any) => void

export const isNuiEnv = typeof window.GetParentResourceName === 'function'

const resourceName = isNuiEnv ? window.GetParentResourceName!() : 'ax_radio'
const listeners = new Map<string, Set<MessageHandler>>()

const devResponses: Record<string, (data: any) => unknown> = {
  createPlaylist: (data) => ({
    id: `dev-${Date.now()}`,
    name: data.name,
    cover: data.cover,
    hue: Math.floor(Math.random() * 360),
    owner_identifier: 'dev:local',
    owner_name: 'You',
    collaborators: [],
    tracks: [],
  }),
  searchPlayers: (data) => {
    const query = String(data.query ?? '').toLowerCase()
    return devPlayers.filter((player) => player.name.toLowerCase().includes(query))
  },
  adminGetData: () => devAdminData(),
  adminStop: () => true,
  adminStopNear: () => 2,
  adminStopAll: () => 4,
  adminWaypoint: () => true,
  adminRenameStation: () => true,
  adminRemoveStation: () => true,
  adminEditStation: () => true,
  adminUnban: () => true,
  adminBan: () => ({ ok: true, stopped: 1 }),
}

export async function fetchNui<T = any>(event: string, data: unknown = {}): Promise<T> {
  if (!isNuiEnv) return (devResponses[event]?.(data) ?? null) as T

  const res = await fetch(`https://${resourceName}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  })
  return res.json() as Promise<T>
}

export function onNuiMessage(action: string, handler: MessageHandler): () => void {
  if (!listeners.has(action)) listeners.set(action, new Set())
  listeners.get(action)!.add(handler)
  return () => listeners.get(action)?.delete(handler)
}

window.addEventListener('message', (event: MessageEvent) => {
  const action = event.data?.action
  if (action) listeners.get(action)?.forEach((handler) => handler(event.data))
})
