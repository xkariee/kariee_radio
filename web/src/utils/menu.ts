import type { MenuAnchor } from '../types'

// Right-click opens at the pointer; a "more" button opens under itself, right-aligned.
export function anchorFrom(e: MouseEvent): MenuAnchor {
  if (e.type === 'contextmenu') return { x: e.clientX, y: e.clientY, align: 'start' }
  const r = (e.currentTarget as HTMLElement).getBoundingClientRect()
  return { x: r.right, y: r.bottom + 6, align: 'end' }
}

// Keyboard (Shift+F10 / Menu key) on a focused row: open just under it.
export function anchorBelow(el: HTMLElement): MenuAnchor {
  const r = el.getBoundingClientRect()
  return { x: r.left + 56, y: r.bottom + 2, align: 'start' }
}
