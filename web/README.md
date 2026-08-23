# Vue 3 + TypeScript + Vite

This template should help get you started developing with Vue 3 and TypeScript in Vite. The template uses Vue 3 `<script setup>` SFCs, check out the [script setup docs](https://v3.vuejs.org/api/sfc-script-setup.html#sfc-script-setup) to learn more.

Learn more about the recommended Project Setup and IDE Support in the [Vue Docs TypeScript Guide](https://vuejs.org/guide/typescript/overview.html#project-setup).

## YouTube search

The search bar looks up songs via the YouTube Data API v3 and plays them through a hidden
YouTube IFrame player. To enable it:

```bash
cp .env.example .env
```

Then paste a YouTube Data API v3 key (see `.env.example` for how to get one) into `.env` as
`VITE_YOUTUBE_API_KEY`, and restart `npm run dev`. Without a key, search shows a notice instead
of results, but the rest of the UI (recently played, playlists, favourites, queue) still works
off the local demo tracks.
