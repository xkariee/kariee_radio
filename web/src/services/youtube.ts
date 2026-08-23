import type { Song } from '../types'

const API_KEY = import.meta.env.VITE_YOUTUBE_API_KEY as string | undefined

export const youtubeConfigured = !!API_KEY

interface YoutubeSearchItem {
  id?: { videoId?: string }
  snippet: {
    title: string
    channelTitle: string
    thumbnails?: { medium?: { url: string }; default?: { url: string } }
  }
}

interface YoutubeVideoItem {
  id: string
  contentDetails: { duration: string }
}

function decodeEntities(text: string): string {
  return text
    .replace(/&amp;/g, '&')
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
}

function parseIsoDuration(iso: string): number {
  const match = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/)
  if (!match) return 0
  const hours = Number(match[1] ?? 0)
  const minutes = Number(match[2] ?? 0)
  const seconds = Number(match[3] ?? 0)
  return hours * 3600 + minutes * 60 + seconds
}

function hueFromId(id: string): number {
  let hash = 0
  for (let i = 0; i < id.length; i++) hash = (hash * 31 + id.charCodeAt(i)) % 360
  return hash
}

export async function searchYouTube(query: string): Promise<Song[]> {
  if (!API_KEY) throw new Error('missing-key')

  const searchUrl =
    'https://www.googleapis.com/youtube/v3/search' +
    `?part=snippet&type=video&videoCategoryId=10&maxResults=12&q=${encodeURIComponent(query)}&key=${API_KEY}`
  const searchRes = await fetch(searchUrl)
  if (!searchRes.ok) throw new Error(`YouTube search failed (${searchRes.status})`)
  const searchJson: { items?: YoutubeSearchItem[] } = await searchRes.json()
  const items = (searchJson.items ?? []).filter((it) => it.id?.videoId)
  const ids = items.map((it) => it.id!.videoId!) as string[]
  if (!ids.length) return []

  const detailsUrl =
    'https://www.googleapis.com/youtube/v3/videos' + `?part=contentDetails&id=${ids.join(',')}&key=${API_KEY}`
  const detailsRes = await fetch(detailsUrl)
  const detailsJson: { items?: YoutubeVideoItem[] } = detailsRes.ok ? await detailsRes.json() : {}
  const durationById = new Map<string, number>()
  for (const item of detailsJson.items ?? []) durationById.set(item.id, parseIsoDuration(item.contentDetails.duration))

  return items.map((it) => {
    const videoId = it.id!.videoId!
    return {
      id: `yt:${videoId}`,
      title: decodeEntities(it.snippet.title),
      artist: decodeEntities(it.snippet.channelTitle),
      duration: durationById.get(videoId) ?? 0,
      hue: hueFromId(videoId),
      source: 'youtube',
      videoId,
      thumbnail: it.snippet.thumbnails?.medium?.url ?? it.snippet.thumbnails?.default?.url ?? null,
    }
  })
}
