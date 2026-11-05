import { computed, watch } from 'vue'
import { fetchVideoById, parseYouTubeId, searchYouTube, youtubeConfigured } from '../services/youtube'
import { saveJson } from '../utils/persist'
import { state } from './state'
import { songsByIds, upsertSong } from './songs'

const MIN_QUERY = 2
const DEBOUNCE_MS = 450
const RECENT_SEARCHES = 8

let searchTimer: ReturnType<typeof setTimeout> | null = null
let searchSeq = 0

export const searchResults = computed(() => songsByIds(state.searchResultIds))

function saveRecentSearches(list: string[]) {
  state.recentSearches = list
  saveJson('recentSearches', list)
}

export function rememberSearch(query: string) {
  const q = query.trim()
  saveRecentSearches([q, ...state.recentSearches.filter((x) => x.toLowerCase() !== q.toLowerCase())].slice(0, RECENT_SEARCHES))
}

export function forgetSearch(query?: string) {
  saveRecentSearches(query ? state.recentSearches.filter((x) => x !== query) : [])
}

async function runSearch(query: string) {
  const seq = ++searchSeq
  state.searching = true
  state.searchError = null
  try {
    const linkId = parseYouTubeId(query)
    const results = linkId ? await fetchVideoById(linkId) : await searchYouTube(query)
    if (seq !== searchSeq) return
    results.forEach(upsertSong)
    state.searchResultIds = results.map((song) => song.id)
    if (results.length && !linkId) rememberSearch(query)
  } catch {
    if (seq !== searchSeq) return
    state.searchResultIds = []
    state.searchError = 'Search failed. Check your connection and try again.'
  } finally {
    if (seq === searchSeq) state.searching = false
  }
}

export function retrySearch() {
  const q = state.searchQuery.trim()
  if (q.length >= MIN_QUERY) runSearch(q)
}

watch(
  () => state.searchQuery,
  (query) => {
    if (searchTimer) clearTimeout(searchTimer)
    const trimmed = query.trim()
    if (trimmed.length < MIN_QUERY || !youtubeConfigured) {
      searchSeq++
      state.searchResultIds = []
      state.searchError = null
      state.searching = false
      return
    }
    state.searching = true
    searchTimer = setTimeout(() => runSearch(trimmed), DEBOUNCE_MS)
  },
)
