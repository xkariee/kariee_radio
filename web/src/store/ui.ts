import { computed } from 'vue'
import type { ConfirmState, MenuAnchor, Song, Toast } from '../types'
import { fetchNui, isNuiEnv } from '../services/nui'
import { state, type PlaylistId } from './state'

let toastSeq = 0

export function toast(text: string, icon = 'check', tone: Toast['tone'] = 'default') {
  const id = ++toastSeq
  state.toasts = [...state.toasts.slice(-2), { id, text, icon, tone }]
  setTimeout(() => dismissToast(id), 2800)
}

export function dismissToast(id: number) {
  state.toasts = state.toasts.filter((t) => t.id !== id)
}

export function askConfirm(confirm: Omit<ConfirmState, 'tone' | 'icon'> & Partial<Pick<ConfirmState, 'tone' | 'icon'>>) {
  state.confirm = { tone: 'default', icon: 'alert', ...confirm }
}

export function openTrackMenu(trackId: string, anchor: MenuAnchor, contextPlaylistId?: PlaylistId) {
  state.popover = null
  state.menu = { kind: 'track', trackId, contextPlaylistId, ...anchor }
}

export function openPlaylistMenu(playlistId: PlaylistId, anchor: MenuAnchor) {
  state.popover = null
  state.menu = { kind: 'playlist', playlistId, ...anchor }
}

export function closeMenu() {
  state.menu = null
}

export function startWidgetEditing() {
  state.settingsOpen = false
  state.menu = null
  state.widgetEditing = true
}

export function finishWidgetEditing(reopenSettings = true) {
  state.widgetEditing = false
  if (reopenSettings) state.settingsOpen = true
}

export const anyModalOpen = computed(
  () =>
    state.createPlaylistOpen ||
    state.editPlaylistId != null ||
    state.inviteePlaylistId != null ||
    state.deletePlaylistId != null ||
    state.settingsOpen ||
    state.shortcutsOpen ||
    state.confirm != null ||
    state.banDraft != null,
)

export function dismissTopLayer(): boolean {
  if (state.widgetEditing) finishWidgetEditing()
  else if (state.menu) state.menu = null
  else if (state.popover) state.popover = null
  else if (state.confirm) state.confirm = null
  else if (state.banDraft) state.banDraft = null
  else if (state.deletePlaylistId != null) state.deletePlaylistId = null
  else if (state.editPlaylistId != null) state.editPlaylistId = null
  else if (state.inviteePlaylistId != null) state.inviteePlaylistId = null
  else if (state.createPlaylistOpen) state.createPlaylistOpen = false
  else if (state.settingsOpen) state.settingsOpen = false
  else if (state.shortcutsOpen) state.shortcutsOpen = false
  else return false
  return true
}

export function close() {
  if (isNuiEnv) fetchNui('close')
  else state.visible = false
}

export async function copyLink(song: Song) {
  if (!song.videoId) return
  const url = `https://www.youtube.com/watch?v=${song.videoId}`
  try {
    await navigator.clipboard.writeText(url)
  } catch {
    const el = document.createElement('textarea')
    el.value = url
    el.style.cssText = 'position:fixed;opacity:0;'
    document.body.appendChild(el)
    el.select()
    document.execCommand('copy')
    el.remove()
  }
  toast('Link copied to clipboard', 'link')
}
