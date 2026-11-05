import type { Song } from '../types'
import { hueFromId } from '../utils/avatar'

const API_KEY = import.meta.env.VITE_YOUTUBE_API_KEY as string | undefined
const API_URL = 'https://www.googleapis.com/youtube/v3'

export const youtubeConfigured = !!API_KEY

interface Snippet {
  title: string
  channelTitle: string
  thumbnails?: { medium?: { url: string }; default?: { url: string } }
}

interface SearchItem {
  id?: { videoId?: string }
  snippet: Snippet
}

interface VideoItem {
  id: string
  snippet?: Snippet
  contentDetails: { duration: string }
}

const ENTITIES: Record<string, string> = { '&amp;': '&', '&#39;': "'", '&quot;': '"', '&lt;': '<', '&gt;': '>' }

function decodeEntities(text: string): string {
  return text.replace(/&(amp|#39|quot|lt|gt);/g, (entity) => ENTITIES[entity])
}

function parseIsoDuration(iso: string): number {
  const match = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/)
  if (!match) return 0
  const [, h = 0, m = 0, s = 0] = match
  return Number(h) * 3600 + Number(m) * 60 + Number(s)
}

async function request<T>(endpoint: string, params: Record<string, string>): Promise<T> {
  if (!API_KEY) throw new Error('missing-key')
  const query = new URLSearchParams({ ...params, key: API_KEY })
  const res = await fetch(`${API_URL}/${endpoint}?${query}`)
  if (!res.ok) throw new Error(`YouTube ${endpoint} failed (${res.status})`)
  return res.json()
}

function toSong(videoId: string, snippet: Snippet, duration: number): Song {
  return {
    id: `yt:${videoId}`,
    title: decodeEntities(snippet.title),
    artist: decodeEntities(snippet.channelTitle),
    duration,
    hue: hueFromId(videoId),
    videoId,
    thumbnail: snippet.thumbnails?.medium?.url ?? snippet.thumbnails?.default?.url ?? null,
  }
}

export function parseYouTubeId(query: string): string | null {
  const q = query.trim()
  const match =
    q.match(/youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/|embed\/|live\/)([\w-]{11})/) || q.match(/youtu\.be\/([\w-]{11})/)
  return match ? match[1] : null
}

export async function fetchVideoById(videoId: string): Promise<Song[]> {
  const { items = [] } = await request<{ items?: VideoItem[] }>('videos', { part: 'snippet,contentDetails', id: videoId })
  return items
    .filter((item) => item.snippet)
    .map((item) => toSong(item.id, item.snippet!, parseIsoDuration(item.contentDetails.duration)))
}

export async function searchYouTube(query: string): Promise<Song[]> {
  const { items = [] } = await request<{ items?: SearchItem[] }>('search', {
    part: 'snippet',
    type: 'video',
    videoCategoryId: '10',
    maxResults: '12',
    q: query,
  })
  const found = items.filter((item) => item.id?.videoId)
  if (!found.length) return []

  const ids = found.map((item) => item.id!.videoId!)
  const details = await request<{ items?: VideoItem[] }>('videos', { part: 'contentDetails', id: ids.join(',') }).catch(
    () => ({ items: [] as VideoItem[] }),
  )
  const durations = new Map((details.items ?? []).map((item) => [item.id, parseIsoDuration(item.contentDetails.duration)]))

  return found.map((item) => {
    const videoId = item.id!.videoId!
    return toSong(videoId, item.snippet, durations.get(videoId) ?? 0)
  })
}
