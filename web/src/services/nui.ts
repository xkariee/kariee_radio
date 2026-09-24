declare global {
  interface Window {
    GetParentResourceName?: () => string
  }
}

export const isNuiEnv = typeof window.GetParentResourceName === 'function'

const resourceName = isNuiEnv ? window.GetParentResourceName!() : 'kariee_radio'

export async function fetchNui<T = any>(event: string, data: unknown = {}): Promise<T> {
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
