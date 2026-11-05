import type { Nav, ViewKind } from '../types'
import { state, type PlaylistId } from './state'

const MAX_HISTORY = 40

function applyNav(nav: Nav) {
  state.view = nav.view
  state.activePlaylistId = nav.playlistId
  state.menu = null
}

export function setView(view: ViewKind, playlistId: PlaylistId | null = null) {
  const current = state.history[state.historyIndex]
  if (!current || current.view !== view || current.playlistId !== playlistId) {
    state.history = [...state.history.slice(0, state.historyIndex + 1), { view, playlistId }].slice(-MAX_HISTORY)
    state.historyIndex = state.history.length - 1
  }
  applyNav({ view, playlistId })
}

export function goBack() {
  if (state.historyIndex <= 0) return
  state.historyIndex -= 1
  applyNav(state.history[state.historyIndex])
}

export function goForward() {
  if (state.historyIndex >= state.history.length - 1) return
  state.historyIndex += 1
  applyNav(state.history[state.historyIndex])
}

export function forgetPlaylistNav(playlistId: PlaylistId) {
  const keptBefore = state.history.slice(0, state.historyIndex + 1).filter((nav) => nav.playlistId !== playlistId).length
  state.history = state.history.filter((nav) => nav.playlistId !== playlistId)
  if (!state.history.length) state.history = [{ view: 'home', playlistId: null }]
  state.historyIndex = Math.max(0, Math.min(keptBefore - 1, state.history.length - 1))
  if (state.activePlaylistId === playlistId) applyNav(state.history[state.historyIndex])
}

export function openSearch(query?: string) {
  if (query !== undefined) state.searchQuery = query
  if (state.view !== 'search') setView('search')
  state.focusSearchSignal++
}
