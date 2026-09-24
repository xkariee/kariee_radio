export function hueFromId(id: string): number {
  let hash = 0
  for (let i = 0; i < id.length; i++) hash = (hash * 31 + id.charCodeAt(i)) % 360
  return hash
}

export function colorForId(id: string): string {
  return `hsl(${hueFromId(id)}, 65%, 62%)`
}
