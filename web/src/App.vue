<script setup lang="ts">
import { computed, onMounted, onUnmounted, watch } from 'vue'
import TopBar from './components/TopBar.vue'
import Sidebar from './components/Sidebar.vue'
import MainContent from './components/MainContent.vue'
import NowPlayingPanel from './components/NowPlayingPanel.vue'
import PlayerBar from './components/PlayerBar.vue'
import ContextMenu from './components/ContextMenu.vue'
import Toasts from './components/Toasts.vue'
import CreatePlaylistModal from './components/modals/CreatePlaylistModal.vue'
import EditPlaylistModal from './components/modals/EditPlaylistModal.vue'
import InviteModal from './components/modals/InviteModal.vue'
import DeleteConfirmModal from './components/modals/DeleteConfirmModal.vue'
import SettingsModal from './components/modals/SettingsModal.vue'
import ShortcutsModal from './components/modals/ShortcutsModal.vue'
import Icon from './components/Icon.vue'
import { store } from './store'
import { ACCENT_HUES, DEFAULT_HUE, applyAccent, applyFlags, applyScale, settings } from './settings'

const { state } = store

// Adaptive accent follows whatever is playing, so the whole radio re-tints per song.
const accentSource = computed(() => {
  if (settings.accent === 'custom') return settings.customAccent
  if (settings.accent === 'adaptive') return store.currentSong.value?.hue ?? DEFAULT_HUE
  return ACCENT_HUES[settings.accent]
})
watch(accentSource, applyAccent, { immediate: true })
watch(() => settings.scale, applyScale, { immediate: true })
watch(() => [settings.reduceMotion, settings.highContrast, settings.density], applyFlags, { immediate: true })

const railOpen = computed(() => settings.nowPlayingPanel)

// `state.visible` mirrors the real NUI focus toggle - hidden until the client sends `open`
// (via the keybind, DJ booth or car), driven entirely by client/main.lua in the FiveM build.
// In the plain-browser dev fallback it just starts visible with a close/reopen tab.
function close() {
  if (store.isNuiEnv) store.close()
  else state.visible = false
}

function isTyping(el: HTMLElement | null) {
  if (!el) return false
  if (el.isContentEditable || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT') return true
  return el.tagName === 'INPUT' && !['range', 'checkbox', 'radio', 'button'].includes((el as HTMLInputElement).type)
}

function onKey(e: KeyboardEvent) {
  if (!state.visible) return
  const target = e.target as HTMLElement | null

  if (e.key === 'Escape') {
    e.preventDefault()
    if (!store.dismissTopLayer()) close()
    return
  }

  if ((e.ctrlKey || e.metaKey) && (e.key === 'f' || e.key === 'k')) {
    e.preventDefault()
    store.openSearch()
    return
  }

  if (isTyping(target) || store.anyModalOpen.value || state.menu || e.ctrlKey || e.metaKey || e.altKey) return

  // Let focused controls keep their native keys (space on a button, arrows on a slider).
  const onButton = !!target?.closest('button, [role="button"], [role="menuitem"], a')
  const onSlider = target?.tagName === 'INPUT'
  const song = store.currentSong.value

  switch (e.key) {
    case ' ':
      if (onButton) return
      e.preventDefault()
      store.togglePlay()
      break
    case 'k':
    case 'K':
      store.togglePlay()
      break
    case 'ArrowRight':
      if (onSlider) return
      e.preventDefault()
      if (e.shiftKey) store.next()
      else store.seekBy(5)
      break
    case 'ArrowLeft':
      if (onSlider) return
      e.preventDefault()
      if (e.shiftKey) store.prev()
      else store.seekBy(-5)
      break
    case 'ArrowUp':
      if (onSlider) return
      e.preventDefault()
      store.setVolume(state.volume + 5)
      break
    case 'ArrowDown':
      if (onSlider) return
      e.preventDefault()
      store.setVolume(state.volume - 5)
      break
    case 'm':
    case 'M':
      store.toggleMute()
      break
    case 's':
    case 'S':
      store.toggleShuffle(true)
      break
    case 'r':
    case 'R':
      if (store.shared.value) store.toast('Repeat is not available on shared radios', 'repeat')
      else store.cycleRepeat(true)
      break
    case 'l':
    case 'L':
      if (song) store.toggleFavorite(song.id)
      break
    case 'q':
    case 'Q':
      store.setView(state.view === 'queue' ? 'home' : 'queue')
      break
    case 'n':
    case 'N':
      settings.nowPlayingPanel = !settings.nowPlayingPanel
      break
    case 'h':
    case 'H':
      store.setView('home')
      break
    case '/':
      e.preventDefault()
      store.openSearch()
      break
    case '?':
      state.shortcutsOpen = true
      break
  }
}

onMounted(() => {
  store.bindNui()
  document.addEventListener('keydown', onKey)
  window.addEventListener('resize', applyScale)
  // FiveM's CEF has no native context menu worth showing.
  document.addEventListener('contextmenu', preventMenu)
})

onUnmounted(() => {
  document.removeEventListener('keydown', onKey)
  window.removeEventListener('resize', applyScale)
  document.removeEventListener('contextmenu', preventMenu)
})

function preventMenu(e: MouseEvent) {
  e.preventDefault()
}
</script>

<template>
  <div class="stage">
    <Transition name="shell" appear>
      <div v-if="state.visible" class="shell" :class="{ 'rail-open': railOpen }">
        <Sidebar class="area-side" style="--i: 0" />
        <main class="panel main-panel area-main" style="--i: 1" aria-label="Browse music">
          <div class="main-wash" aria-hidden="true" />
          <TopBar @close="close" />
          <MainContent />
        </main>
        <!-- Always mounted: the column width animates and the panel slides/fades at a fixed width,
             so nothing inside reflows or pops while it opens and closes. -->
        <div class="rail-slot" :class="{ open: railOpen }">
          <NowPlayingPanel />
        </div>
        <PlayerBar class="area-dock" style="--i: 3" />
        <Toasts />
      </div>

      <button v-else-if="!store.isNuiEnv" class="reopen-tab" @click="state.visible = true">
        <Icon name="radio" :size="16" />
        Open Radio
      </button>
    </Transition>

    <ContextMenu />
    <CreatePlaylistModal v-if="state.createPlaylistOpen" />
    <EditPlaylistModal v-if="state.editPlaylistId != null" />
    <InviteModal v-if="state.inviteePlaylistId != null" />
    <DeleteConfirmModal v-if="state.deletePlaylistId != null" />
    <SettingsModal v-if="state.settingsOpen" />
    <ShortcutsModal v-if="state.shortcutsOpen" />
  </div>
</template>

<style scoped>
.stage {
  width: 100%;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
}

.shell {
  position: relative;
  width: min(144rem, 96vw);
  height: min(86rem, 94vh);
  display: grid;
  /* The rail column (which already includes its 1.2rem gap) animates via the registered
     --rail-w property, so the main panel widens/narrows smoothly instead of snapping. The dock
     spans main + rail, so its width never changes. */
  --rail-w: 0rem;
  grid-template-columns: 25.6rem 1.2rem minmax(0, 1fr) var(--rail-w);
  grid-template-rows: minmax(0, 1fr) auto;
  grid-template-areas:
    'side . main rail'
    'side . dock dock';
  column-gap: 0;
  row-gap: 1.2rem;
  transition: --rail-w 0.55s var(--ease-out);
}

.shell.rail-open {
  --rail-w: 32.2rem;
}

.area-side {
  grid-area: side;
}
.area-main {
  grid-area: main;
}
.area-dock {
  grid-area: dock;
}

.rail-slot {
  grid-area: rail;
  position: relative;
  min-width: 0;
  animation: panel-in 0.5s var(--ease-out) both;
  animation-delay: 90ms;
}

/* Fixed width, pinned to the column's left edge: as the column shrinks the panel is carried to
   the right while it fades, as if sliding back behind the main panel. */
.shell .rail-slot > :deep(.rail) {
  position: absolute;
  top: 0;
  bottom: 0;
  left: 1.2rem;
  width: 31rem;
  animation: none;
  opacity: 0;
  transform: translateX(3rem) scale(0.97);
  visibility: hidden;
  transition:
    opacity 0.32s var(--ease),
    transform 0.55s var(--ease-out),
    visibility 0s linear 0.55s;
}

.shell .rail-slot.open > :deep(.rail) {
  opacity: 1;
  transform: none;
  visibility: visible;
  transition:
    opacity 0.45s var(--ease) 0.08s,
    transform 0.55s var(--ease-out),
    visibility 0s;
}

/* shared floating-panel look, used by every top-level region */
.shell :deep(.panel) {
  position: relative;
  background: var(--panel);
  border-radius: var(--r-xl);
  box-shadow: var(--shadow-panel), var(--highlight);
  border: 0.1rem solid var(--line);
  min-height: 0;
  min-width: 0;
  overflow: hidden;
  animation: panel-in 0.5s var(--ease-out) both;
  animation-delay: calc(var(--i, 0) * 45ms);
}

@keyframes panel-in {
  from {
    opacity: 0;
    transform: translateY(1.2rem) scale(0.985);
  }
}

.main-panel {
  display: flex;
  flex-direction: column;
}

/* ambient tint that follows the accent (and therefore the song) */
.main-wash {
  position: absolute;
  inset: 0 0 auto 0;
  height: 32rem;
  background:
    radial-gradient(60rem 26rem at 8% -8%, var(--accent-deep), transparent 70%),
    radial-gradient(40rem 20rem at 95% -10%, var(--accent-soft), transparent 70%);
  opacity: 0.9;
  pointer-events: none;
}

.shell-enter-active {
  transition: opacity 0.25s var(--ease);
}
.shell-leave-active {
  transition:
    opacity 0.14s var(--ease),
    transform 0.14s var(--ease);
}
.shell-enter-from,
.shell-leave-to {
  opacity: 0;
}
.shell-leave-to {
  transform: scale(0.98);
}

.reopen-tab {
  display: inline-flex;
  align-items: center;
  gap: 0.8rem;
  height: 4.4rem;
  padding: 0 2rem;
  border-radius: var(--r-pill);
  background: var(--panel);
  border: 0.1rem solid var(--line-2);
  color: var(--text-h);
  font-size: 1.35rem;
  font-weight: 700;
  box-shadow: var(--shadow-panel);
  transition:
    transform 0.18s var(--ease),
    border-color 0.18s var(--ease);
}

.reopen-tab svg {
  color: var(--accent);
}

.reopen-tab:hover {
  transform: translateY(-0.2rem);
  border-color: var(--accent-line);
}
</style>
