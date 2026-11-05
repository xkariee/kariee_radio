import type { MenuAnchor } from '../types'

export function anchorFrom(e: MouseEvent): MenuAnchor {
  if (e.type === 'contextmenu') return { x: e.clientX, y: e.clientY, align: 'start' }
  const r = (e.currentTarget as HTMLElement).getBoundingClientRect()
  return { x: r.right, y: r.bottom + 6, align: 'end' }
}

export function anchorBelow(el: HTMLElement): MenuAnchor {
  const r = el.getBoundingClientRect()
  return { x: r.left + 56, y: r.bottom + 2, align: 'start' }
}
